# 13. CI/CD с Docker и GitHub Actions

## Цель

Автоматизировать сборку, проверку и публикацию Docker-образа через GitHub Actions:
lint → build → test → scan → push.

---

## Теория

### Пайплайн: от коммита до реестра

```text
git push
    │
    ▼
┌─────────────────────────────────────────────┐
│ GitHub Actions Workflow                     │
│                                             │
│  lint ──► build ──► test ──► scan ──► push  │
│                                             │
│  hadolint   docker    verify.sh   trivy     │
│  yamllint   build     curl /      image     │
│  shellcheck           healthz               │
└─────────────────────────────────────────────┘
    │
    ▼
Docker Hub / GHCR / ECR
```

### Аутентификация в реестре

**Docker Hub:**
```yaml
- uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}   # Access Token, не пароль!
```

**GitHub Container Registry (GHCR) — встроен в GitHub:**
```yaml
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}      # автоматически доступен
```

### Тегирование образов

```yaml
- uses: docker/metadata-action@v5
  id: meta
  with:
    images: ghcr.io/${{ github.repository }}
    tags: |
      type=semver,pattern={{version}}          # v1.2.3
      type=semver,pattern={{major}}.{{minor}}  # v1.2
      type=sha,prefix=sha-                     # sha-abc1234
      type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}
```

Правило: `latest` только для `main`-ветки. Теги по semver — для релизов.

### Кеш сборки

```yaml
- uses: docker/build-push-action@v6
  with:
    cache-from: type=gha          # кеш GitHub Actions
    cache-to: type=gha,mode=max
```

Без кеша каждый `pip install` / `npm install` занимает время заново.

### Multi-platform сборка

```yaml
- uses: docker/setup-qemu-action@v3    # эмуляция ARM

- uses: docker/setup-buildx-action@v3  # расширенный builder

- uses: docker/build-push-action@v6
  with:
    platforms: linux/amd64,linux/arm64
    push: true
```

### Сканирование в CI — gate на уязвимости

```yaml
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE }}
    format: table
    exit-code: 1                 # падаем при HIGH/CRITICAL
    severity: HIGH,CRITICAL
    ignore-unfixed: true         # игнорировать без патча
```

---

## Полный workflow: build-push.yml

```yaml
# .github/workflows/build-push.yml
name: Build and Push

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]

env:
  IMAGE: ghcr.io/${{ github.repository }}/app

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Lint Dockerfile
        uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: docker-lab/02-images-dockerfile/lab/Dockerfile

      - name: Lint YAML
        run: |
          pip install yamllint
          yamllint docker-lab/

      - name: Lint Shell scripts
        uses: ludeeus/action-shellcheck@master
        with:
          scandir: docker-lab/

  build-test:
    name: Build & Test
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build image (no push)
        uses: docker/build-push-action@v6
        with:
          context: docker-lab/02-images-dockerfile/lab
          load: true                        # загрузить в локальный docker
          tags: ${{ env.IMAGE }}:test
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Run smoke test
        run: |
          docker run -d --name test-app -p 8090:8090 ${{ env.IMAGE }}:test
          sleep 3
          curl --fail http://localhost:8090/healthz
          docker stop test-app

  scan:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: build-test
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build for scanning
        uses: docker/build-push-action@v6
        with:
          context: docker-lab/02-images-dockerfile/lab
          load: true
          tags: ${{ env.IMAGE }}:scan

      - name: Trivy vulnerability scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE }}:scan
          format: table
          exit-code: 1
          severity: HIGH,CRITICAL
          ignore-unfixed: true

  push:
    name: Push to Registry
    runs-on: ubuntu-latest
    needs: [build-test, scan]
    if: github.event_name != 'pull_request'   # не пушим для PR
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU (multi-arch)
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.IMAGE }}
          tags: |
            type=semver,pattern={{version}}
            type=sha,prefix=sha-
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}

      - name: Build and push multi-arch
        uses: docker/build-push-action@v6
        with:
          context: docker-lab/02-images-dockerfile/lab
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## Практика

### 1. Создайте workflow в репозитории

```bash
mkdir -p .github/workflows
cp docker-lab/13-cicd-github-actions/examples/build-push.yml \
   .github/workflows/build-push.yml
```

### 2. Добавьте секреты в GitHub

Settings → Secrets and variables → Actions → New repository secret:
- `DOCKERHUB_USERNAME` — ваш логин Docker Hub (если используете Docker Hub)
- `DOCKERHUB_TOKEN` — Access Token из hub.docker.com/settings/security

> GHCR не требует дополнительных секретов — `GITHUB_TOKEN` встроен.

### 3. Проверьте workflow локально через act

[act](https://github.com/nektos/act) позволяет запускать GitHub Actions локально:

```bash
# Установка (macOS/Linux)
brew install act
# или через curl
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Запустить только job lint
act -j lint

# Запустить с конкретным событием
act push
```

### 4. Запустите сканирование вручную

```bash
# Соберите образ
docker build -t myapp:test docker-lab/02-images-dockerfile/lab

# Запустите Trivy как в CI
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity HIGH,CRITICAL myapp:test
```

---

## Проверка

- Workflow запускается при `git push` и проходит все jobs.
- `lint` job ловит ошибки в Dockerfile/YAML/shell.
- `build-test` собирает образ и проверяет `/healthz`.
- `scan` блокирует push при HIGH/CRITICAL уязвимостях.
- `push` публикует образ с правильными тегами.
- Понимаете разницу `load: true` и `push: true` в build-push-action.

---

## Типовые ошибки

| Ошибка | Симптом | Исправление |
|---|---|---|
| `GITHUB_TOKEN` нет прав на packages | `denied: permission_denied` | Settings → Actions → Read and write permissions |
| `push: true` без login | `unauthorized` | Добавить `docker/login-action` перед build-push |
| Нет `needs:` между jobs | scan запускается до build | Добавить `needs: build-test` |
| Тег `latest` на feature-ветке | Перетирает production | Условие `enable=${{ github.ref == 'refs/heads/main' }}` |
| Нет кеша | Каждый билд с нуля, медленно | Добавить `cache-from/cache-to: type=gha` |

---

## Вопросы

1. Чем `load: true` отличается от `push: true` в build-push-action?
2. Почему Access Token лучше пароля для Docker Hub в CI?
3. Как `needs:` определяет порядок и зависимости jobs?
4. Зачем нужен QEMU при multi-platform сборке?
5. Что такое `GITHUB_TOKEN` и откуда он берётся?

---

## Дополнительные задания

- Добавьте job с `docker compose config` для валидации compose-файлов.
- Настройте уведомление в Slack при падении pipeline.
- Добавьте генерацию SBOM (Software Bill of Materials) через Syft.
- Реализуйте деплой на сервер по SSH после успешного push.

---

## Файлы модуля

- `examples/build-push.yml` — полный workflow для копирования.
- `lab/` — тестовое приложение для практики.
