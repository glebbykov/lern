# 13. CI/CD: GitHub Actions + GHCR

## Что делает этот модуль

В этом репозитории уже настроен реальный pipeline. При пуше в `main` или создании тега `v*` запускается:

```text
Lint → Build + Test → Scan (Trivy) → Push to GHCR
```

Workflow файл: [.github/workflows/docker-lab-13-build-push.yml](../../../.github/workflows/docker-lab-13-build-push.yml)

Приложение: [lab/](lab/) — Go HTTP-сервер с `/healthz`

---

## Структура pipeline

```text
on: push main / tag v* / PR
         │
    ┌────▼────┐
    │  lint   │  hadolint → Dockerfile качество
    └────┬────┘
         │ needs: lint
    ┌────▼──────────┐
    │ build-test    │  docker buildx → load → smoke test /healthz
    └────┬──────────┘
         │ needs: build-test
    ┌────▼────┐
    │  scan   │  trivy → EXIT 1 при HIGH/CRITICAL CVE
    └────┬────┘
         │ needs: [build-test, scan]
         │ if: не PR
    ┌────▼────┐
    │  push   │  multi-arch push → ghcr.io/<owner>/cicd-app
    └─────────┘
```

---

## Часть 1 — Запустить pipeline

### Триггер через коммит в main

```bash
# Внести любое изменение в lab/
echo "// updated" >> docker-lab/13-cicd-github-actions/lab/main.go
git add docker-lab/13-cicd-github-actions/lab/main.go
git commit -m "ci: trigger pipeline"
git push origin main
```

Открой: **Actions** → **13 – Build, Scan, Push to GHCR** → смотри логи каждого job.

### Триггер через тег (релиз)

```bash
git tag v1.0.0
git push origin v1.0.0
```

После успешного pipeline образ появится в GHCR:
`ghcr.io/<owner>/cicd-app:1.0.0`, `1.0`, `sha-abc1234`

---

## Часть 2 — Разобрать каждый job

### job: lint

```yaml
- uses: hadolint/hadolint-action@v3.1.0
  with:
    dockerfile: docker-lab/13-cicd-github-actions/lab/Dockerfile
    failure-threshold: warning
```

```bash
# То же самое локально
docker run --rm -i hadolint/hadolint \
  < docker-lab/13-cicd-github-actions/lab/Dockerfile
# Нет вывода = нет ошибок
```

Hadolint проверяет:
- `FROM` без pinned тега → `DL3007`
- `latest` в `FROM` → `DL3007`
- `RUN apt-get update` без `apt-get install` в одном слое → `DL3009`
- `ADD` вместо `COPY` → `DL3020`

### job: build-test

```yaml
- uses: docker/build-push-action@v6
  with:
    load: true    # в локальный daemon, НЕ push
    push: false
```

```bash
# Локально: собрать и проверить
docker buildx build \
  --load \
  -t cicd-app:test \
  docker-lab/13-cicd-github-actions/lab

docker run -d --name smoke -p 8080:8080 cicd-app:test
curl http://localhost:8080/healthz   # ok
docker rm -f smoke
```

### job: scan

```yaml
- uses: aquasecurity/trivy-action@master
  with:
    exit-code: "1"        # pipeline упадёт при HIGH/CRITICAL
    ignore-unfixed: true  # игнорировать CVE без доступного патча
```

```bash
# Локально
docker run --rm aquasec/trivy:latest image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  cicd-app:test
# 0 vulnerabilities (distroless + Go 1.24)
```

### job: push

```yaml
permissions:
  packages: write   # без этого push в ghcr.io упадёт

- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}   # встроен в каждый workflow
```

**`GITHUB_TOKEN`** — автоматически доступен в каждом workflow, добавлять вручную не нужно. Permissions нужно явно указать в `jobs.<job>.permissions`.

---

## Часть 3 — Тегирование образов

```yaml
- uses: docker/metadata-action@v5
  with:
    tags: |
      type=semver,pattern={{version}}
      type=semver,pattern={{major}}.{{minor}}
      type=sha,prefix=sha-
      type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}
```

| Событие | Теги образа |
|---|---|
| `push` в `main` | `latest`, `sha-abc1234` |
| `git tag v1.3.0` | `1.3.0`, `1.3`, `sha-abc1234` |
| PR в `main` | только `sha-abc1234` (без `latest`) |

```bash
# Проверить что образ появился в GHCR после push
docker pull ghcr.io/<owner>/cicd-app:latest
docker run --rm ghcr.io/<owner>/cicd-app:latest
# hello from <hostname>
```

---

## Часть 4 — Multi-platform сборка

```yaml
- uses: docker/setup-qemu-action@v3    # QEMU для эмуляции ARM
- uses: docker/setup-buildx-action@v3

- uses: docker/build-push-action@v6
  with:
    platforms: linux/amd64,linux/arm64
    push: true
```

```bash
# Проверить что образ содержит обе платформы
docker buildx imagetools inspect ghcr.io/<owner>/cicd-app:latest
# Platform: linux/amd64
# Platform: linux/arm64
```

**Зачем QEMU:** GitHub Actions runner — x86. Для сборки под arm64 нужна программная эмуляция через QEMU (медленнее, но не нужен реальный ARM-runner).

---

## Часть 5 — Кеш сборки

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

| Параметр | Что делает |
|---|---|
| `type=gha` | Хранит кеш в GitHub Actions Cache |
| `mode=max` | Кешировать все промежуточные слои |
| `mode=min` | Только финальный образ |

```bash
# Посмотреть использование кеша в Actions
# Actions → <workflow run> → Build image → кликни на шаг
# Строки "CACHED" в логах = кеш сработал
```

---

## Часть 6 — Сделать образ публичным (GHCR)

По умолчанию образ в GHCR — приватный. Чтобы сделать публичным:

1. Открой: **github.com/\<owner\>** → **Packages** → найди `cicd-app`
2. Package settings → **Make public**

Или через Settings репозитория → Packages → подключить к репозиторию.

---

## Практика: адаптировать под свой проект

```bash
# Скопировать шаблон в свой репозиторий
cp docker-lab/13-cicd-github-actions/examples/build-push.yml \
   .github/workflows/build-push.yml

# Отредактировать переменные в начале файла:
# IMAGE: ghcr.io/<owner>/<my-app>
# BUILD_CONTEXT: ./  (путь до Dockerfile)
# APP_PORT: 8080     (порт healthz)
```

Шаблон: [examples/build-push.yml](examples/build-push.yml)

---

## Типовые ошибки

| Ошибка | Симптом | Причина и fix |
|---|---|---|
| `denied: permission_denied` при push | job push падает | Нет `permissions: packages: write` в job |
| `unauthorized: unauthenticated` | login step падает | Не добавлен шаг `docker/login-action` |
| `load: true` + `platforms: amd64,arm64` | buildx error | Нельзя загрузить multi-arch локально — убери `load` или укажи одну платформу |
| `latest` пушится с PR | Мутирует production образ | Условие `enable=${{ github.ref == 'refs/heads/main' }}` |
| Trivy блокирует push | `exit-code: 1` сработал | CVE в базовом образе — обнови или добавь `.trivyignore` |
| Кеш не работает | Каждый билд с нуля | Убедись что `cache-from: type=gha` есть в обоих jobs |

---

## Вопросы для самопроверки

1. Зачем `permissions: packages: write` — почему его нет глобально?
2. `load: true` vs `push: true` — что выбрать для smoke test?
3. `GITHUB_TOKEN` — что это и откуда берётся?
4. Зачем QEMU при multi-platform сборке на x86 runner?
5. Почему `latest` должен пушиться только из `main`, а не из PR?
6. `ignore-unfixed: true` в Trivy — это компромисс или плохая практика?
7. Как получить digest образа после push и записать его в release notes?

---

## Файлы модуля

| Файл | Назначение |
|---|---|
| [lab/Dockerfile](lab/Dockerfile) | Образ приложения (multi-stage, distroless) |
| [lab/main.go](lab/main.go) | Go HTTP-сервер с `/healthz` |
| [lab/go.mod](lab/go.mod) | Go module |
| [examples/build-push.yml](examples/build-push.yml) | Шаблон workflow для своего проекта |
| [.github/workflows/docker-lab-13-build-push.yml](../../../.github/workflows/docker-lab-13-build-push.yml) | Реальный workflow этого репозитория |

## Cleanup

```bash
./cleanup.sh
```
