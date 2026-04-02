# 13. CI/CD с Docker и GitHub Actions

## Зачем это важно

Ручная сборка и пуш образов — источник ошибок: забытые шаги, разные результаты на разных машинах, нет истории. CI/CD автоматизирует весь путь от коммита до реестра с верификацией на каждом шаге.

```text
git push
    │
    ▼
lint ──► build ──► test ──► scan ──► push
  │         │        │        │        │
hadolint  docker   curl     trivy    GHCR /
yamllint  buildx  /healthz  HIGH,    Docker Hub
shellchk          smoke    CRIT
```

---

## Часть 1 — Что проверяет каждый job

### lint

```yaml
- name: Lint Dockerfile
  uses: hadolint/hadolint-action@v3.1.0
  with:
    dockerfile: path/to/Dockerfile
```

Hadolint проверяет:
- `FROM` без pinned тега → `DL3007`
- `apt-get update` без `apt-get install` в одном `RUN` → `DL3009`
- `ADD` вместо `COPY` → `DL3020`
- `latest` в `FROM` → `DL3007`

```bash
# Запустить hadolint локально
docker run --rm -i hadolint/hadolint < docker-lab/07-security/lab/Dockerfile
# Нет вывода = нет ошибок
```

### build-test

```yaml
- uses: docker/build-push-action@v6
  with:
    load: true      # загрузить в локальный docker (не пушить)
    push: false
```

**`load: true` vs `push: true`:**

| Флаг | Что делает | Когда использовать |
|---|---|---|
| `load: true` | Загружает в локальный docker daemon | Для тестов в том же job |
| `push: true` | Пушит в registry | Только после успешных тестов |

### scan

```yaml
- uses: aquasecurity/trivy-action@master
  with:
    exit-code: "1"            # падаем при HIGH/CRITICAL
    severity: HIGH,CRITICAL
    ignore-unfixed: true      # игнорировать CVE без патча
```

```bash
# То же самое локально
docker run --rm aquasec/trivy:latest image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  myapp:test
```

---

## Часть 2 — Тегирование через metadata-action

```yaml
- uses: docker/metadata-action@v5
  id: meta
  with:
    images: ghcr.io/${{ github.repository }}/app
    tags: |
      type=semver,pattern={{version}}          # v1.2.3 → 1.2.3
      type=semver,pattern={{major}}.{{minor}}  # v1.2.3 → 1.2
      type=sha,prefix=sha-                     # sha-abc1234
      type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}
```

**Правила:**
- `latest` — только на коммитах в `main`
- Semver-теги — только при `git tag v1.2.3`
- `sha-` теги — всегда (трассировка коммита)

```bash
# Проверить какие теги будут созданы:
# При push в main:         sha-abc1234, latest
# При git tag v1.3.0:      1.3.0, 1.3, sha-abc1234
# При PR в main:           sha-abc1234 (без latest)
```

---

## Часть 3 — Кеш сборки

```yaml
- uses: docker/build-push-action@v6
  with:
    cache-from: type=gha          # читать кеш из GitHub Actions cache
    cache-to: type=gha,mode=max   # писать все слои в кеш
```

```bash
# Локальный кеш через registry
docker buildx build \
  --cache-from type=registry,ref=localhost:5000/myapp:cache \
  --cache-to   type=registry,ref=localhost:5000/myapp:cache,mode=max \
  -t myapp:test .
```

**`mode=max` vs `mode=min`:**
- `min` — кешировать только финальный образ
- `max` — кешировать все промежуточные слои (быстрее при частичных изменениях)

---

## Часть 4 — Multi-platform сборка

```yaml
- uses: docker/setup-qemu-action@v3    # эмуляция ARM на x86

- uses: docker/setup-buildx-action@v3  # расширенный builder

- uses: docker/build-push-action@v6
  with:
    platforms: linux/amd64,linux/arm64
    push: true
```

```bash
# Локально: multi-platform с push в локальный registry
docker run -d --name registry -p 5000:5000 registry:2
docker buildx create --use --name multiarch
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push \
  -t localhost:5000/myapp:multiarch \
  docker-lab/08-build-advanced/lab

# Проверить манифест
docker buildx imagetools inspect localhost:5000/myapp:multiarch
# Mediatype: application/vnd.oci.image.index.v1+json
# Platform: linux/amd64
# Platform: linux/arm64
```

---

## Часть 5 — Аутентификация в registry

### GHCR (встроен в GitHub, без дополнительных секретов)

```yaml
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}  # автоматически доступен
```

Разрешения для пакетов:
```yaml
jobs:
  push:
    permissions:
      contents: read
      packages: write   # ← обязательно для ghcr.io push
```

### Docker Hub

```yaml
- uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}   # Access Token, не пароль!
```

Создать токен: hub.docker.com → Account Settings → Security → Access Tokens

---

## Часть 6 — Запуск workflow локально через act

```bash
# Установка
brew install act     # macOS
# или
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Запустить только lint job
act -j lint

# Запустить весь workflow на событие push
act push

# С секретами
act push --secret GITHUB_TOKEN=<token>

# Посмотреть список jobs в workflow
act --list
```

---

## Практика

### Шаг 1 — Создать workflow

```bash
mkdir -p .github/workflows
cp docker-lab/13-cicd-github-actions/examples/build-push.yml \
   .github/workflows/build-push.yml
```

### Шаг 2 — Добавить секреты в GitHub

Settings → Secrets and variables → Actions:
- `DOCKERHUB_USERNAME` — логин Docker Hub (если не используете GHCR)
- `DOCKERHUB_TOKEN` — Access Token

### Шаг 3 — Проверить lint локально

```bash
# Hadolint
docker run --rm -i hadolint/hadolint \
  < docker-lab/02-images-dockerfile/lab/Dockerfile

# Yamllint
pip install yamllint && yamllint docker-lab/

# Shellcheck
shellcheck docker-lab/**/*.sh
```

### Шаг 4 — Проверить scan локально

```bash
docker build -t myapp:ci docker-lab/02-images-dockerfile/lab

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  myapp:ci
```

---

## Типовые ошибки

| Ошибка | Симптом | Исправление |
|---|---|---|
| `packages: write` не выставлен | `denied: permission_denied` при push в GHCR | Добавить в `permissions:` |
| `push: true` без `login-action` | `unauthorized` | Добавить шаг логина до build-push |
| Нет `needs:` между jobs | scan запускается до build | `needs: build-test` |
| `latest` на feature-ветке | Перетирает production образ | Условие `enable=${{ github.ref == 'refs/heads/main' }}` |
| Нет кеша | Каждый билд с нуля, медленно | `cache-from/cache-to: type=gha` |
| `load: true` + `platforms: amd64,arm64` | Ошибка — нельзя загрузить multi-platform | Использовать `push: true` или одну платформу |

---

## Вопросы для самопроверки

1. Чем `load: true` отличается от `push: true`?
2. Почему Access Token лучше пароля в CI?
3. Что такое `GITHUB_TOKEN` и откуда он берётся?
4. Зачем QEMU при multi-platform сборке?
5. Как `needs:` управляет порядком jobs?
6. Почему `ignore-unfixed: true` в Trivy — разумный компромисс?
7. Как узнать digest образа после push в CI и записать его в release notes?

---

## Файлы модуля

- [examples/build-push.yml](examples/build-push.yml) — полный workflow для копирования

## Cleanup

```bash
./cleanup.sh
```
