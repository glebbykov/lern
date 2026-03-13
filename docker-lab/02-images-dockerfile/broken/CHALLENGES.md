# Dockerfile: найди и исправь

Каждое задание — сломанный или неоптимальный Dockerfile.
Найдите все проблемы, объясните почему это плохо, исправьте.

Раскрывайте подсказки по одной — только если застряли.
Решение смотрите в последнюю очередь.

---

## Задание 1 — Медленная пересборка

Приложение на Python. После любого изменения кода `docker build`
заново скачивает все зависимости. На каждый коммит — несколько минут.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY . .

RUN pip install --no-cache-dir -r requirements.txt

CMD ["python", "app.py"]
```

Найдите все проблемы. Сколько их?

<details>
<summary>💡 Подсказка 1</summary>

Docker строит образ слой за слоем.
Если содержимое слоя не изменилось — он берётся из кеша.
Как только один слой инвалидируется — **все последующие** пересобираются заново.

Посмотрите на `COPY . .` — что он копирует? Когда этот слой изменяется?

</details>

<details>
<summary>💡 Подсказка 2</summary>

`requirements.txt` меняется редко. `app.py` — при каждом коммите.

Сейчас они попадают в образ одной командой `COPY . .`.
Это значит: изменил `app.py` → инвалидировался слой с `COPY` →
следующий слой `RUN pip install` пересобирается с нуля.

Как разделить копирование зависимостей и исходников на два отдельных шага?

</details>

<details>
<summary>💡 Подсказка 3</summary>

Две оставшиеся проблемы не связаны с кешем:

1. В `build context` попадают `.git`, `__pycache__`, `.env` и всё остальное.
   Есть механизм, позволяющий исключить ненужное — аналог `.gitignore`.

2. Приложение запускается от имени какого пользователя?
   Проверьте: `docker run --rm myapp id`

</details>

<details>
<summary>✅ Решение</summary>

**Проблемы:**

1. `COPY . .` перед `pip install` — любое изменение `.py` инвалидирует кеш зависимостей.
2. Нет `.dockerignore` — лишние файлы раздувают context и могут утечь.
3. Нет `USER` — процесс запускается от `root`.

**Исправленный Dockerfile:**

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Шаг 1: только зависимости — этот слой кешируется надолго
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Шаг 2: исходники — меняются часто, но pip install уже в кеше
COPY app.py ./

RUN adduser --disabled-password --gecos "" appuser
USER appuser

CMD ["python", "app.py"]
```

**`.dockerignore`:**

```gitignore
.git
__pycache__
*.pyc
.env
venv/
.venv/
```

**Как проверить размер context:**

```bash
docker build --no-cache -t test . 2>&1 | grep "Sending build context"
```

</details>

---

## Задание 2 — Утечка секрета

CI-система сообщает, что в образе найден API-ключ.
Команда безопасности требует срочного исправления.

```dockerfile
FROM node:20-alpine

WORKDIR /app

ARG API_KEY
ENV API_KEY=${API_KEY}

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

CMD ["node", "server.js"]
```

Сборка: `docker build --build-arg API_KEY=sk-prod-abc123 -t myapp .`

<details>
<summary>💡 Подсказка 1</summary>

В Docker образе хранятся не только файлы, но и метаданные каждого слоя:
переменные окружения, команды сборки, аргументы.

Как посмотреть историю слоёв образа вместе со всеми командами?

```bash
docker history myapp --no-trunc
```

</details>

<details>
<summary>💡 Подсказка 2</summary>

`ARG` — переменная сборки. Её значение фиксируется в истории слоя,
в котором оно использовалось.

`ENV` — переменная окружения. Она записывается прямо в конфиг образа
и видна через `docker inspect` каждому, кто имеет доступ к образу.

Проверьте оба места:

```bash
docker history myapp --no-trunc | grep -i api_key
docker inspect myapp --format '{{json .Config.Env}}'
```

</details>

<details>
<summary>💡 Подсказка 3</summary>

Секрет нужен только в рантайме (приложение его читает при старте),
а не при сборке образа.

Нужно ли передавать `API_KEY` во время `docker build` вообще?
Где лучше его передавать: при сборке или при запуске контейнера?

</details>

<details>
<summary>✅ Решение</summary>

**Проблемы:**

1. `ARG API_KEY` → значение видно в `docker history --no-trunc`.
2. `ENV API_KEY=${API_KEY}` → записывается в конфиг образа, видно через `docker inspect`.
3. Секрет навсегда остаётся в образе — нельзя убрать, не пересобрав.

**Вариант А — передавать секрет в рантайме (рекомендуется):**

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
# API_KEY убран из Dockerfile полностью
CMD ["node", "server.js"]
```

```bash
# При запуске:
docker run -e API_KEY=sk-prod-abc123 myapp
# Или через файл (не в git!):
docker run --env-file .env myapp
```

**Вариант Б — Compose secrets (монтируется как файл):**

```yaml
secrets:
  api_key:
    file: ./secrets/api_key.txt   # файл не в git

services:
  app:
    secrets:
      - api_key
    # читать из /run/secrets/api_key в приложении
```

**Вариант В — если секрет нужен именно при сборке (npm private registry):**

```dockerfile
# syntax=docker/dockerfile:1.7
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci --omit=dev
# Секрет НЕ попадает в слой и не виден в history
```

```bash
docker build --secret id=npmrc,src=.npmrc .
```

</details>

---

## Задание 3 — Огромный образ

Go-приложение. Образ весит 1.2 GB. Задача: уменьшить до минимума.

```dockerfile
FROM golang:1.22

WORKDIR /app

COPY . .

RUN go build -o server main.go

EXPOSE 8080

CMD ["/app/server"]
```

```bash
docker images myapp
# REPOSITORY  TAG     SIZE
# myapp       latest  1.21GB
```

<details>
<summary>💡 Подсказка 1</summary>

`golang:1.22` — это образ с полным Go-тулчейном: компилятор, stdlib,
инструменты (`go fmt`, `go vet`, `go test`...). Они нужны **только при сборке**.

Что реально нужно для **запуска** скомпилированного Go-приложения?

</details>

<details>
<summary>💡 Подсказка 2</summary>

Go компилирует в **статически слинкованный бинарник** — один исполняемый файл
без внешних зависимостей. Для его запуска не нужны ни Go, ни glibc, ни даже bash.

В Docker есть паттерн **multi-stage build**: один `FROM` для сборки,
другой — для финального образа. Они изолированы, в финальный попадает только то,
что явно скопировано через `COPY --from=builder`.

</details>

<details>
<summary>💡 Подсказка 3</summary>

Существуют образы специально для таких финальных стадий:

- `scratch` — абсолютно пустой образ (0 MB). Подходит для полностью статических бинарников.
- `gcr.io/distroless/static-debian12:nonroot` — минимум CA-сертификатов, часовых зон,
  запускается от non-root. Рекомендуется для Go.
- `alpine:3.x` — ~5 MB, есть shell (удобнее отлаживать).

Ещё: при сборке добавьте `CGO_ENABLED=0` и флаги `-ldflags="-s -w"`.
Зачем они нужны?

</details>

<details>
<summary>✅ Решение</summary>

**Проблемы:**

1. Финальный образ содержит весь Go-тулчейн (~800 MB лишнего).
2. Нет multi-stage build — builder и runtime в одном слое.
3. `COPY . .` без предварительного `go mod download` — нет кеша зависимостей.
4. Нет `CGO_ENABLED=0` — бинарник может быть динамически слинкован.
5. Нет `USER` — запуск от root.

**Исправленный Dockerfile:**

```dockerfile
# syntax=docker/dockerfile:1.7
FROM golang:1.22-alpine AS builder

WORKDIR /src

# Шаг 1: зависимости (кешируются отдельно от исходников)
COPY go.mod go.sum ./
RUN go mod download

# Шаг 2: исходники
COPY . .

# Статический бинарник; -s -w убирают debug-символы → меньше размер
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w" \
    -o /out/server main.go

# ─────────────────────────────────────────────────────
# Финальный образ — только бинарник, нет shell, нет Go
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /out/server /server

EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

**Результат:**

```text
До:    1.21 GB  (golang:1.22 + исходники + тулчейн)
После: ~10 MB   (distroless + бинарник)
```

**Почему distroless, а не scratch?**

- Есть CA-сертификаты → HTTPS-запросы работают из коробки.
- Есть часовые зоны (`/usr/share/zoneinfo`).
- Запускается от non-root по умолчанию.

</details>

---

## Задание 4 — Контейнер не останавливается

`docker stop` зависает на 10 секунд, потом контейнер убивается принудительно.
Приложение не успевает завершить открытые соединения и транзакции.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

RUN adduser --disabled-password --gecos "" appuser
USER appuser

CMD ["sh", "-c", "python app.py"]
```

<details>
<summary>💡 Подсказка 1</summary>

`docker stop` не убивает контейнер сразу. Он посылает сигнал `SIGTERM`
процессу с PID 1, ждёт 10 секунд, и только потом посылает `SIGKILL`.

Правильно написанное приложение перехватывает `SIGTERM` и завершается
gracefully: закрывает соединения, дописывает данные, отвечает на in-flight запросы.

Кто в этом контейнере является PID 1?

</details>

<details>
<summary>💡 Подсказка 2</summary>

Запустите контейнер и проверьте:

```bash
docker exec <container> ps aux
```

Вы увидите два процесса: `sh` и `python app.py`.
`sh` — PID 1. `python` — дочерний процесс с другим PID.

`SIGTERM` приходит на PID 1. Что делает `sh` с этим сигналом?

</details>

<details>
<summary>💡 Подсказка 3</summary>

Shell (`sh`, `bash`) **не форвардит сигналы** дочерним процессам.
`python app.py` никогда не получит `SIGTERM` — только `SIGKILL` через 10 секунд.

Одно из исправлений умещается в одну строку Dockerfile.
Подсказка: `CMD ["sh", "-c", "python app.py"]` — это shell form.
А как выглядит exec form, в котором Python сразу становится PID 1?

</details>

<details>
<summary>✅ Решение</summary>

**Проблема:**

`CMD ["sh", "-c", "python app.py"]` запускает shell как PID 1.
Shell не форвардит `SIGTERM` — Python его не получает.
Docker ждёт grace period (10s) и отправляет `SIGKILL`. Graceful shutdown невозможен.

**Исправление 1 — exec form (самое простое):**

```dockerfile
# Python сам становится PID 1
CMD ["python", "app.py"]
```

```bash
# Проверка после исправления:
docker exec <container> ps aux
# PID 1  python app.py  ← теперь python получает SIGTERM напрямую
```

**Исправление 2 — dumb-init (для сложных случаев):**

```dockerfile
RUN pip install dumb-init

ENTRYPOINT ["dumb-init", "--"]
CMD ["python", "app.py"]
```

`dumb-init` — минимальный init-процесс:
- Корректно форвардит все сигналы дочерним процессам.
- Собирает зомби-процессы (если приложение форкает дочерние).

**Исправление 3 — `exec` в entrypoint-скрипте:**

```bash
#!/bin/sh
# entrypoint.sh — exec заменяет shell на python → python становится PID 1
exec python app.py
```

**Когда достаточно exec form, когда нужен dumb-init:**

| Ситуация | Решение |
|---|---|
| Простой сервис, один процесс | `CMD ["python", "app.py"]` |
| Нужен entrypoint-скрипт (настройка конфига при старте) | `exec` в конце скрипта |
| Приложение форкает воркеры, нужна уборка зомби | `dumb-init` |

</details>

---

## Задание 5 — Контейнер не проходит healthcheck

`docker compose ps` показывает `unhealthy`. API отвечает на запросы,
но `depends_on: condition: service_healthy` держит другие сервисы в ожидании.

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

RUN adduser --disabled-password --gecos "" appuser
USER appuser

EXPOSE 8090

HEALTHCHECK CMD curl -f http://localhost:8090/healthz || exit 1

CMD ["python", "app.py"]
```

```bash
docker ps
# STATUS: Up 30 seconds (health: starting) → (unhealthy)
```

<details>
<summary>💡 Подсказка 1</summary>

Healthcheck выполняется **внутри контейнера**.
Значит `curl` должен быть установлен **в образе**.

Проверьте:

```bash
docker exec <container> which curl
docker exec <container> curl --version
```

Что отвечает образ `python:3.12-slim`?

</details>

<details>
<summary>💡 Подсказка 2</summary>

`python:3.12-slim` — минимальный образ. `curl` там нет.
Каждый вызов healthcheck завершается ошибкой `command not found`,
контейнер накапливает failures → переходит в `unhealthy`.

Есть как минимум два способа не устанавливать `curl`:
1. Использовать встроенные возможности Python.
2. Использовать утилиту, которая уже есть в slim-образах.

Что есть в Python для HTTP-запросов без внешних библиотек?

</details>

<details>
<summary>💡 Подсказка 3</summary>

Вторая проблема — тайминг. Посмотрите на параметры HEALTHCHECK:

```bash
docker inspect <container> --format '{{json .Config.Healthcheck}}'
```

По умолчанию: `interval=30s`, `timeout=30s`, `start-period=0s`, `retries=3`.

`start-period=0s` означает: первая проверка сразу при старте контейнера.
Python-приложение может стартовать 2-5 секунд — за это время уже
накапливаются failures. Как дать приложению время на инициализацию?

</details>

<details>
<summary>✅ Решение</summary>

**Проблемы:**

1. `curl` не установлен в `python:3.12-slim` → healthcheck всегда падает.
2. Нет `--start-period` → проверки начинаются до готовности приложения.
3. Нет явных `--interval`, `--timeout` → используются дефолты, которые часто не подходят.

**Исправление:**

```dockerfile
# Вариант А — Python (встроенный urllib, curl не нужен)
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c \
        "import urllib.request; urllib.request.urlopen('http://localhost:8090/healthz')" \
    || exit 1
```

```dockerfile
# Вариант Б — wget (обычно есть в slim)
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:8090/healthz || exit 1
```

```dockerfile
# Вариант В — установить curl (увеличивает образ на ~3 MB)
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8090/healthz || exit 1
```

**Что означает каждый параметр:**

| Параметр | Default | Рекомендация |
|---|---|---|
| `--interval` | 30s | 10–15s для dev, 30s для prod |
| `--timeout` | 30s | 3–5s (не ждать вечно) |
| `--start-period` | 0s | время старта приложения |
| `--retries` | 3 | 3–5 |

**Как смотреть историю healthcheck:**

```bash
docker inspect <container> --format '{{json .State.Health}}' | python -m json.tool
```

</details>

---

## Задание 6 — Права на файлы и read-only FS

Приложение работает нормально, но при включении `read_only: true` падает:

```text
PermissionError: [Errno 13] Permission denied: '/app/logs/app.log'
```

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN adduser --disabled-password --gecos "" appuser
RUN mkdir -p /app/logs

USER appuser
CMD ["python", "app.py"]
```

```yaml
# compose.yaml
services:
  app:
    build: .
    read_only: true
    cap_drop: [ALL]
```

<details>
<summary>💡 Подсказка 1</summary>

`read_only: true` означает, что вся файловая система контейнера
монтируется в режиме только для чтения.

Это включает `/app/logs`. Попытка записи в любое место → `Permission denied`.

Где в Linux можно писать данные без постоянного диска?

</details>

<details>
<summary>💡 Подсказка 2</summary>

`tmpfs` — это файловая система в оперативной памяти.
Она монтируется поверх конкретных путей и **разрешает запись** даже
при `read_only: true`.

Данные в `tmpfs` исчезают при остановке контейнера — это нормально для
временных файлов, логов и PID-файлов.

В `compose.yaml` это выглядит как:
```yaml
tmpfs:
  - /путь/к/директории
```

</details>

<details>
<summary>💡 Подсказка 3</summary>

Есть ещё одна проблема в Dockerfile.
`RUN mkdir -p /app/logs` создаёт директорию от `root`.
После `USER appuser` — пользователь `appuser` может не иметь прав на запись в неё.

Как создать директорию с правильным владельцем сразу?

</details>

<details>
<summary>✅ Решение</summary>

**Проблемы:**

1. `read_only: true` запрещает запись во весь контейнер, включая `/app/logs`.
2. `mkdir -p /app/logs` создаёт директорию от `root` — `appuser` не может писать.

**Исправление Dockerfile:**

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN adduser --disabled-password --gecos "" appuser \
    && mkdir -p /app/logs \
    && chown -R appuser:appuser /app/logs

USER appuser
CMD ["python", "app.py"]
```

**Исправление compose.yaml:**

```yaml
services:
  app:
    build: .
    read_only: true
    cap_drop: [ALL]
    security_opt:
      - no-new-privileges:true
    tmpfs:
      - /app/logs    # временные логи в RAM
      - /tmp         # временные файлы
      - /var/run     # PID-файлы, сокеты
```

**Если логи нужно сохранять — volume вместо tmpfs:**

```yaml
services:
  app:
    read_only: true
    volumes:
      - app_logs:/app/logs   # персистентный том

volumes:
  app_logs:
```

**Выбор между tmpfs и volume:**

| | tmpfs | volume |
|---|---|---|
| Скорость | Быстро (RAM) | Медленнее (диск) |
| Персистентность | Нет | Да |
| Подходит для | `/tmp`, логи за сессию, сокеты | Данные БД, важные файлы |

</details>

---

## Задание 7 — Node.js: модули пропадают при старте

Разработчик поднял стенд, приложение падает сразу при старте:

```text
Error: Cannot find module 'express'
```

Хотя `RUN npm ci` в Dockerfile есть, и `node_modules` установлены при сборке образа.

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY . .

RUN npm ci

EXPOSE 3000
CMD ["node", "server.js"]
```

```yaml
services:
  app:
    build: .
    volumes:
      - .:/app
    ports:
      - "3000:3000"
```

<details>
<summary>💡 Подсказка 1</summary>

Посмотрите на `volumes` в compose.yaml:
```yaml
volumes:
  - .:/app
```

Что делает этот bind-mount?
Директория `.` с хоста монтируется в `/app` контейнера.

Что находится в `/app` контейнера до монтирования? А после?

</details>

<details>
<summary>💡 Подсказка 2</summary>

Bind-mount **полностью перекрывает** содержимое `/app` в контейнере
содержимым директории с хоста.

`node_modules`, установленные при `RUN npm ci` — исчезают.
Вместо них — `node_modules` с хоста (или их отсутствие, если они не установлены).

Если на хосте `node_modules` нет или они собраны под другую ОС/архитектуру
(macOS → Linux) — `Cannot find module`.

Как защитить `/app/node_modules` от перекрытия bind-mount'ом?

</details>

<details>
<summary>💡 Подсказка 3</summary>

В Docker можно смонтировать **именованный том** поверх конкретной
поддиректории, которую перекрыл bind-mount.

Порядок монтирования: сначала bind-mount `.:/app`,
потом `node_modules:/app/node_modules` — он монтируется поверх.

При первом запуске Docker автоматически заполняет именованный том
содержимым из образа (только если том пустой).

Также нужно починить Dockerfile — там тоже есть проблема с кешем.

</details>

<details>
<summary>✅ Решение</summary>

**Проблема:**

`volumes: - .:/app` перекрывает `/app` в контейнере директорией хоста.
`node_modules` из образа исчезают. Если на хосте они не установлены
или собраны под другую платформу — приложение падает.

**Исправление compose.yaml:**

```yaml
services:
  app:
    build: .
    volumes:
      - .:/app                          # исходники с хоста (hot reload)
      - node_modules:/app/node_modules  # модули из образа, защищены от перекрытия

volumes:
  node_modules:   # именованный том — Docker заполняет из образа при первом старте
```

**Исправление Dockerfile (плюс кеш зависимостей):**

```dockerfile
FROM node:20-alpine

WORKDIR /app

# Зависимости отдельно — кешируются пока не изменится package.json
COPY package*.json ./
RUN npm ci

# Исходники отдельно
COPY . .

RUN addgroup -S app && adduser -S -G app app
USER app

EXPOSE 3000
CMD ["node", "server.js"]
```

**Как это работает:**

```text
docker compose up
  ↓
1. bind-mount .:/app    → /app = содержимое хоста
2. volume node_modules:/app/node_modules
                        → /app/node_modules = модули из образа
                          (поверх bind-mount, хост не видит эту поддиректорию)
```

**Важно:** после изменения `package.json` нужно пересобрать образ
и пересоздать том:

```bash
docker compose down -v          # удалить тома
docker compose up -d --build    # пересобрать и запустить
```

</details>

---

## Задание 8 — Все проблемы сразу

Финальное задание. Dockerfile содержит сразу несколько типичных проблем.
Найдите все, объясните каждую, напишите исправленную версию.

```dockerfile
FROM ubuntu:latest

RUN apt-get update
RUN apt-get install -y python3 python3-pip git curl vim wget

COPY . /app

WORKDIR /app

RUN pip3 install -r requirements.txt

ENV DB_PASSWORD=supersecret123
ENV DEBUG=true

EXPOSE 8080
EXPOSE 22

CMD python3 app.py
```

<details>
<summary>💡 Подсказка 1 — базовый образ</summary>

Строка `FROM ubuntu:latest` содержит **два** отдельных антипаттерна.

Первый: почему `ubuntu` — плохой выбор для Python-приложения?
Какие образы специально созданы для Python?

Второй: что означает тег `latest`?
Что произойдёт если через месяц запустить `docker build` снова?

</details>

<details>
<summary>💡 Подсказка 2 — слои и пакеты</summary>

Проблема с двумя отдельными `RUN apt-get`:

```dockerfile
RUN apt-get update         # ← кешируется отдельно
RUN apt-get install -y ... # ← если добавить пакет через неделю — update не перезапустится
```

Кеш `apt-get update` устаревает, а `apt-get install` берёт пакеты
из старых индексов. Результат — неожиданные версии или ошибки.

Как правильно объединить эти две команды в один `RUN`?

Также: `git`, `vim`, `wget` — они нужны в production-образе?

</details>

<details>
<summary>💡 Подсказка 3 — секреты, сигналы, пользователь</summary>

Три проблемы в нижней части Dockerfile:

1. `ENV DB_PASSWORD=supersecret123` — что с этим не так?
   Проверьте: `docker inspect <image> --format '{{json .Config.Env}}'`

2. `EXPOSE 22` — зачем SSH в контейнере? Чем заменить?

3. `CMD python3 app.py` — это shell form или exec form?
   Кто будет PID 1? (вспомните задание 4)

</details>

<details>
<summary>✅ Полное решение</summary>

**Найденные проблемы (10 штук):**

| # | Проблема | Почему плохо |
|---|---|---|
| 1 | `ubuntu:latest` — `ubuntu` | Огромный образ, много лишнего. Используйте `python:3.12-slim` |
| 2 | `ubuntu:latest` — `latest` | Непредсказуемые обновления, нет reproducibility |
| 3 | Два отдельных `RUN apt-get` | Кеш `update` устаревает — установка из старых индексов |
| 4 | `git vim wget` в production | Лишние CVE, лишний размер образа |
| 5 | `COPY . /app` — нет `.dockerignore` | В образ попадает `.git`, `.env`, тесты |
| 6 | `COPY . /app` до `WORKDIR` + до pip | Нет оптимизации кеша зависимостей |
| 7 | `pip3 install` без `--no-cache-dir` | Кеш pip остаётся в слое — лишние MB |
| 8 | `ENV DB_PASSWORD=supersecret123` | Секрет в образе, виден через `docker inspect` |
| 9 | `EXPOSE 22` (SSH) | SSH в контейнере — антипаттерн; используйте `docker exec` |
| 10 | `CMD python3 app.py` (shell form) | `sh` = PID 1, не форвардит SIGTERM |
| 11 | Нет `USER` | Приложение запускается от root |

**Исправленный Dockerfile:**

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Сначала зависимости (кеш)
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Потом исходники
COPY app.py ./

RUN adduser --disabled-password --gecos "" appuser
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c \
        "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')" \
    || exit 1

CMD ["python", "app.py"]
```

**Секреты — только в рантайме:**

```bash
docker run -e DB_PASSWORD="$DB_PASSWORD" -e DEBUG=false myapp
# или:
docker run --env-file .env myapp   # .env в .gitignore!
```

**`.dockerignore`:**

```gitignore
.git
__pycache__
*.pyc
.env
.env.*
tests/
docs/
*.log
```

</details>

---

## Бонус: инструменты диагностики

```bash
# Статический анализ Dockerfile
docker run --rm -i hadolint/hadolint < Dockerfile

# CVE и мисконфигурации в образе
docker run --rm aquasec/trivy:latest image myapp:latest

# Слои образа и их размеры
docker history myapp:latest

# Пользователь и переменные окружения
docker inspect myapp:latest --format '{{.Config.User}}'
docker inspect myapp:latest --format '{{json .Config.Env}}' | python -m json.tool

# Изучить содержимое образа без запуска
docker run --rm --entrypoint sh myapp:latest -c "id && ls -la /app && env"

# Посмотреть PID 1 в работающем контейнере
docker exec <container> ps aux
```
