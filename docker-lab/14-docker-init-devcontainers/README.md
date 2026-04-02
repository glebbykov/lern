# 14. Docker Init и Dev Containers

## Зачем это важно

Написание Dockerfile с нуля — ошибко-генерирующий процесс. `docker init` автоматически генерирует Dockerfile, compose.yaml и .dockerignore для типовых стеков. Dev Containers стандартизируют dev-окружение через `.devcontainer/devcontainer.json` — на любой машине одно и то же окружение за минуту.

```text
Без docker init                  С docker init
────────────────────────────────────────────────
Ручной Dockerfile         →    docker init → готовый Dockerfile за 10 сек
Забыл .dockerignore       →    .dockerignore сгенерирован
Неоптимальный кеш        →    Правильный порядок слоёв
Нет compose.yaml          →    compose.yaml с healthcheck
```

---

## Prereq

- Docker Desktop 4.18+ (для `docker init`) или Docker Engine 27+.
- Понимание Dockerfile (модуль 02), Compose (модуль 03).
- Опционально: VS Code с расширением Dev Containers.

---

## Часть 1 — docker init: генерация проекта

### Что умеет docker init

```bash
# Проверить доступность
docker init --help
# Usage: docker init [OPTIONS]
# Подсказки: Go, Python, Node, Rust, Java, ...
```

`docker init` анализирует проект (наличие `go.mod`, `requirements.txt`, `package.json`) и генерирует:
- `Dockerfile` — multi-stage, с правильным кешированием
- `compose.yaml` — с healthcheck и volumes
- `.dockerignore` — исключает `.git`, `node_modules`, `__pycache__`

### Практика: Go-проект

```bash
# Перейти в директорию с Go-проектом
cd lab/go-app

# Запустить docker init и выбрать Go
docker init
# ? What application platform does your project use? Go
# ? What version of Go do you want to use? 1.24
# ? What's the relative directory of your main package? .
# ? What port does your server listen on? 8080
```

### Изучить результат

```bash
# Посмотреть сгенерированный Dockerfile
cat Dockerfile
# FROM golang:1.24-alpine AS build
# WORKDIR /src
# COPY go.sum go.mod ./
# RUN go mod download
# COPY . .
# RUN go build -o /bin/server .
# FROM alpine:3.20 AS final
# ...

# Посмотреть compose.yaml
cat compose.yaml

# Посмотреть .dockerignore
cat .dockerignore
```

### Собрать и проверить

```bash
docker compose up -d --build
curl http://localhost:8080/healthz
# ok
docker compose down
```

---

## Часть 2 — docker init для Python

```bash
cd ../python-app

docker init
# ? Platform: Python
# ? Version: 3.12
# ? Port: 8090
# ? Command: python app.py
```

### Сравнить с рукописным Dockerfile

```bash
# Сгенерированный — обычно использует virtualenv и группу app
cat Dockerfile

# Наш рукописный (из модуля 02)
cat ../../02-images-dockerfile/lab/Dockerfile

# Ключевые различия:
# 1. docker init добавляет bind mount для горячей перезагрузки
# 2. docker init использует --mount=type=cache для pip
# 3. docker init создаёт non-root user по умолчанию
```

### Анализ качества сгенерированного Dockerfile

```bash
# Hadolint — проверка качества
docker run --rm -i hadolint/hadolint < Dockerfile
# Обычно docker init генерирует чистый Dockerfile без warnings
```

---

## Часть 3 — docker init для Node.js

```bash
cd ../node-app

docker init
# ? Platform: Node
# ? Version: 22
# ? Package manager: npm
# ? Port: 3000
# ? Command: node server.js
```

### Ключевые паттерны для Node.js

```bash
cat Dockerfile
# Обратите внимание:
# 1. COPY package*.json ./  ← перед COPY . . (кеш npm install)
# 2. npm ci  ← вместо npm install (воспроизводимые зависимости)
# 3. USER node  ← встроенный non-root user в node-образах
# 4. .dockerignore включает node_modules/
```

---

## Часть 4 — Когда docker init не достаточно

`docker init` покрывает ~80% типовых случаев. Когда нужна ручная работа:

| Ситуация | Почему docker init не справится |
|---|---|
| Multi-service compose | Генерирует только один сервис |
| BuildKit secrets (`--mount=type=secret`) | Не добавляет автоматически |
| Distroless runtime | Обычно генерирует alpine/debian, не distroless |
| Сложные entrypoint-скрипты | Генерирует простой `CMD` |
| Custom healthcheck с зависимостями | Генерирует базовый healthcheck |

### Практика: доработка результата

```bash
cd ../go-app

# 1. Заменить alpine runtime на distroless
# В Dockerfile замените:
#   FROM alpine:3.20 AS final
# На:
#   FROM gcr.io/distroless/static-debian12:nonroot AS final

# 2. Добавить cap_drop в compose.yaml
# services:
#   server:
#     cap_drop:
#       - ALL

# 3. Добавить resource limits
# services:
#   server:
#     deploy:
#       resources:
#         limits:
#           memory: 128M
```

---

## Часть 5 — Dev Containers: воспроизводимая dev-среда

Dev Container — это спецификация (devcontainers.dev) для описания контейнеризированной среды разработки. Поддерживается VS Code, JetBrains, GitHub Codespaces.

### Зачем это нужно

```text
Проблема                          Dev Container решение
──────────────────────────────────────────────────────
"У меня работает" ™               Одинаковая среда у всех
Настройка занимает 2 часа         docker compose up — готово
Конфликт версий Go/Python/Node    Каждый проект в своём контейнере
CI отличается от dev              Общий Dockerfile для dev и CI
```

### Структура

```text
.devcontainer/
├── devcontainer.json    ← конфигурация среды
├── Dockerfile           ← опциональный custom-образ
└── compose.yaml         ← опциональный compose для БД/Redis/etc
```

### Минимальный devcontainer.json

```json
{
  "name": "Go Dev",
  "image": "mcr.microsoft.com/devcontainers/go:1.24",
  "customizations": {
    "vscode": {
      "extensions": [
        "golang.go",
        "ms-azuretools.vscode-docker"
      ]
    }
  },
  "forwardPorts": [8080],
  "postCreateCommand": "go mod download"
}
```

### Практика: создать Dev Container

```bash
# Посмотреть готовый пример
cat lab/devcontainer/.devcontainer/devcontainer.json

# Открыть в VS Code (если установлен)
# VS Code: Cmd/Ctrl + Shift + P → "Dev Containers: Open Folder in Container"
# Или: code lab/devcontainer/
```

### Dev Container с Compose (полный стек)

```json
{
  "name": "Full Stack Dev",
  "dockerComposeFile": "compose.yaml",
  "service": "app",
  "workspaceFolder": "/workspace",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-azuretools.vscode-docker"
      ]
    }
  },
  "forwardPorts": [8090, 5432],
  "postCreateCommand": "pip install -r requirements.txt"
}
```

```yaml
# .devcontainer/compose.yaml
services:
  app:
    build:
      context: ..
      dockerfile: .devcontainer/Dockerfile
    volumes:
      - ..:/workspace:cached
    command: sleep infinity    # dev-контейнер работает бесконечно

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: devpass
    volumes:
      - pg_data:/var/lib/postgresql/data

volumes:
  pg_data:
```

---

## Часть 6 — Broken: плохой результат docker init

```bash
# Собрать сломанный вариант — docker init с неправильными настройками
docker build -t dockerlab/init-bad:dev ./broken

# Проблема 1: запуск от root
docker run --rm dockerlab/init-bad:dev id
# uid=0(root)

# Проблема 2: нет .dockerignore → огромный контекст
docker build --no-cache -t test ./broken 2>&1 | grep "Sending build context"
# Sending build context: > 50 MB (включает .git, node_modules)

# Проблема 3: неправильный порядок COPY
# При изменении любого файла pip install перезапускается
docker rmi test 2>/dev/null || true
```

### Исправление

```bash
# Сравни broken/Dockerfile с lab/python-app/Dockerfile
diff broken/Dockerfile lab/python-app/Dockerfile.fixed
# Ключевые отличия:
# 1. USER app добавлен
# 2. COPY requirements.txt до COPY . .
# 3. .dockerignore создан
```

---

## Типовые ошибки

| Ошибка | Последствие | Исправление |
|---|---|---|
| `docker init` в директории без `go.mod`/`requirements.txt` | Генерирует generic Dockerfile | Создать файл зависимостей перед `docker init` |
| Не проверять сгенерированный Dockerfile | Может не соответствовать security-требованиям | Всегда ревьюить и дорабатывать |
| Dev Container без `postCreateCommand` | Зависимости не установлены после создания | Добавить `pip install`/`npm ci`/`go mod download` |
| Dev Container с `:latest` образом | Неоднозначная среда разработки | Использовать конкретный тег |
| Копировать `.devcontainer/` без адаптации | Порты, расширения, зависимости не подходят | Адаптировать под свой проект |

---

## Вопросы для самопроверки

1. В каких случаях `docker init` достаточно, а когда нужна ручная доработка?
2. Что генерирует `docker init` помимо Dockerfile?
3. Зачем Dev Container использует `sleep infinity` как command?
4. Как Dev Container отличается от обычного `docker compose up`?
5. Какие правки нужно внести в результат `docker init` для production?
6. Чем `npm ci` лучше `npm install` в Dockerfile?

---

## Файлы модуля

| Файл | Назначение |
|---|---|
| `lab/go-app/` | Go-проект для демонстрации `docker init` |
| `lab/python-app/` | Python-проект для `docker init` |
| `lab/node-app/` | Node.js-проект для `docker init` |
| `lab/devcontainer/` | Пример Dev Container с compose |
| `broken/` | Плохой Dockerfile без .dockerignore и с root |
| `checks/verify.sh` | Автоматическая проверка |

## Cleanup

```bash
./cleanup.sh
```
