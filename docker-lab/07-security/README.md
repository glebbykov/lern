# 07. Security и hardening

## Зачем это важно

Контейнер по умолчанию — не изолированная среда. Процесс в контейнере работает от `root`, имеет 14 Linux capabilities и полный доступ к ФС. Hardening — это последовательное сужение этих привилегий.

```text
Дефолтный контейнер              После hardening
─────────────────────────────────────────────────
user: root                  →    user: app (uid 1000)
capabilities: 14            →    capabilities: 0
rw filesystem               →    read_only: true + tmpfs
secrets in ENV              →    /run/secrets/ (Compose secrets)
image: ubuntu:latest        →    python:3.12-slim / distroless
```

---

## Часть 1 — Non-root пользователь

### Проблема

```bash
# Запустим любой официальный образ — кто мы?
docker run --rm nginx:1.27-alpine id
# uid=0(root) gid=0(root)  ← root!

# Что это значит: если процесс выбьется из контейнера,
# он получит root-доступ к хосту
```

### Исправление в Dockerfile

```dockerfile
# Alpine
RUN addgroup -S app && adduser -S -G app app
USER app

# Debian/Ubuntu
RUN addgroup --system app && adduser --system --ingroup app app
USER app
```

### Практика

```bash
# Собираем hardened образ
docker build -t dockerlab/secure-app:dev ./lab

# Проверяем пользователя двумя способами
docker run --rm dockerlab/secure-app:dev id
# uid=100(app) gid=101(app)  ← не root

docker inspect dockerlab/secure-app:dev --format '{{.Config.User}}'
# app
```

---

## Часть 2 — Read-only filesystem + tmpfs

Если атакующий получил RCE в контейнере — read-only ФС лишает его возможности оставить backdoor, положить вредоносный файл или модифицировать бинарники.

```yaml
services:
  app:
    read_only: true          # корневая ФС только для чтения
    tmpfs:
      - /tmp                 # RAM-диск — для временных файлов
      - /var/run             # для PID-файлов и сокетов
```

### Проверка read-only

```bash
docker compose -f lab/compose.yaml up -d --build

# Проверить флаг
docker inspect security-app --format '{{.HostConfig.ReadonlyRootfs}}'
# true

# Убедиться что tmpfs смонтирован
docker inspect security-app \
  --format '{{range .HostConfig.Tmpfs}}tmpfs: {{.}}{{println}}{{end}}'

# Проверить что /tmp доступен для записи
docker exec security-app sh -c "touch /tmp/ok && echo 'tmp: writable'"

# Проверить что /app недоступен для записи
docker exec security-app sh -c "touch /app/nope || echo 'rootfs: readonly'"
```

### Что бывает без tmpfs при read_only

```bash
# Запустим сломанный пример — flask пытается писать в /tmp без tmpfs
docker run --rm --read-only python:3.12-slim \
  sh -c "python3 -c 'import tempfile; tempfile.mkstemp()' || echo 'crash: no tmpfs'"
```

---

## Часть 3 — Linux capabilities: принцип минимальных привилегий

```yaml
services:
  app:
    cap_drop:
      - ALL                  # сбросить все ~14 дефолтных capabilities
    cap_add:
      - NET_BIND_SERVICE     # добавить обратно только нужное
```

### Что это даёт

```bash
# Без cap_drop: что умеет процесс по умолчанию?
docker run --rm alpine:3.20 cat /proc/1/status | grep CapEff
# CapEff: 00000000a80425fb  ← много бит выставлено

# После cap_drop: ALL
docker run --rm --cap-drop ALL alpine:3.20 cat /proc/1/status | grep CapEff
# CapEff: 0000000000000000  ← ничего

# Проверить capabilities запущенного контейнера
docker inspect security-app \
  --format 'drop: {{.HostConfig.CapDrop}}  add: {{.HostConfig.CapAdd}}'
# drop: [ALL]  add: []
```

### Часто нужные capabilities

| Capability | Когда нужна |
|---|---|
| `NET_BIND_SERVICE` | Биндинг на порты < 1024 (443, 80) |
| `CHOWN` | `chown` в entrypoint-скрипте |
| `SETUID`/`SETGID` | `su`, `sudo` внутри контейнера |
| `SYS_PTRACE` | `strace`, `gdb` — только для отладки |

---

## Часть 4 — no-new-privileges

```yaml
security_opt:
  - no-new-privileges:true
```

Запрещает процессу повысить привилегии через `setuid`-биты, `sudo` или `execve`. Без этого флага `cap_drop: ALL` можно обойти через setuid-бинарники внутри контейнера.

```bash
# Проверить флаг
docker inspect security-app \
  --format '{{.HostConfig.SecurityOpt}}'
# [no-new-privileges:true]
```

---

## Часть 5 — Секреты: как не утечь

### Антипаттерн: секрет в ENV/ARG

```bash
# Собираем сломанный образ
docker build -t dockerlab/secret-leak:bad ./broken

# Секрет виден в истории слоёв — НАВСЕГДА
docker history dockerlab/secret-leak:bad --no-trunc | grep -i secret
# ENV API_TOKEN=super-secret-token  ← виден всем кто имеет доступ к образу

# Даже если добавить RUN unset API_TOKEN — секрет остаётся в предыдущем слое
docker image inspect dockerlab/secret-leak:bad \
  --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -i token
# API_TOKEN=super-secret-token
```

### Правильный подход: Compose secrets

```yaml
# compose.yaml
secrets:
  db_password:
    file: ./secrets/db_password.txt   # файл НЕ в git

services:
  app:
    secrets:
      - db_password
    # доступен внутри как: /run/secrets/db_password
```

```bash
# Проверить что секрет доступен только как файл, не в env
docker exec security-app cat /run/secrets/db_password 2>/dev/null || echo 'нет секрета в compose.yaml'
docker exec security-app env | grep -i password || echo 'пароля нет в переменных окружения'
```

### Сравнение способов

| Способ | Видимость | Рекомендация |
|---|---|---|
| `ENV` в Dockerfile | `docker history`, любой с образом | Никогда |
| `ARG` в Dockerfile | `docker history --no-trunc` | Никогда |
| `environment:` в compose | git-история, логи CI | Только dev |
| `.env` файл (не в git) | только хост | Приемлемо для dev |
| `secrets:` в compose | bind-mount `/run/secrets/` | Рекомендуется |
| Vault / AWS SSM | внешняя система | Лучший вариант prod |

---

## Часть 6 — Сканирование образа через Trivy

```bash
# Полное сканирование — CVE в OS-пакетах и зависимостях
docker run --rm aquasec/trivy:latest image dockerlab/secure-app:dev

# Только HIGH и CRITICAL
docker run --rm aquasec/trivy:latest image \
  --severity HIGH,CRITICAL dockerlab/secure-app:dev

# Поиск секретов в слоях образа
docker run --rm aquasec/trivy:latest image \
  --scanners secret dockerlab/secret-leak:bad

# Проверка Dockerfile на мисконфигурации
docker run --rm -v "$(pwd)":/work aquasec/trivy:latest config /work/lab

# Сравнение двух образов
docker run --rm aquasec/trivy:latest image --severity HIGH,CRITICAL python:3.12
docker run --rm aquasec/trivy:latest image --severity HIGH,CRITICAL python:3.12-slim
# slim содержит существенно меньше CVE
```

### Что проверяет Trivy

| Тип сканирования | Что находит |
|---|---|
| `vuln` (дефолт) | CVE в OS-пакетах, pip/npm/go.sum |
| `secret` | Токены, ключи, пароли в слоях образа |
| `config` | Мисконфигурации Dockerfile (root, latest, ADD) |
| `license` | Несовместимые лицензии зависимостей |

---

## Часть 7 — Минимальный базовый образ

```bash
# Сравним размеры
docker pull python:3.12        && docker image ls python:3.12        --format '{{.Size}}'
docker pull python:3.12-slim   && docker image ls python:3.12-slim   --format '{{.Size}}'
docker pull python:3.12-alpine && docker image ls python:3.12-alpine --format '{{.Size}}'

# python:3.12         ~1.0 GB
# python:3.12-slim    ~150 MB
# python:3.12-alpine  ~55 MB

# Число CVE обычно растёт с размером
docker run --rm aquasec/trivy:latest image --severity CRITICAL python:3.12
docker run --rm aquasec/trivy:latest image --severity CRITICAL python:3.12-slim
```

**Distroless** — нет shell, нет пакетного менеджера:
```bash
# Попытаться войти в distroless контейнер
docker run --rm gcr.io/distroless/python3 sh
# OCI runtime error — нет /bin/sh
# Это фича: атакующий не может запустить интерактивную сессию
```

---

## Комплексная проверка hardening

```bash
# Запустить лабораторный стенд
docker compose -f lab/compose.yaml up -d --build

# 1. Non-root
docker inspect security-app --format '{{.Config.User}}'
# app (не root)

# 2. Read-only FS
docker inspect security-app --format '{{.HostConfig.ReadonlyRootfs}}'
# true

# 3. Capabilities
docker inspect security-app --format 'drop={{.HostConfig.CapDrop}} add={{.HostConfig.CapAdd}}'
# drop=[ALL] add=[]

# 4. no-new-privileges
docker inspect security-app --format '{{.HostConfig.SecurityOpt}}'
# [no-new-privileges:true]

# 5. Сервис отвечает несмотря на все ограничения
curl http://localhost:8083/healthz
```

---

## Broken примеры

| Файл | Проблема |
|---|---|
| `broken/Dockerfile.secret` | `ENV API_TOKEN=...` — секрет в слое образа |

```bash
# Собери и найди секрет
docker build -t dockerlab/secret-leak:bad ./broken
docker history dockerlab/secret-leak:bad --no-trunc | grep API_TOKEN
docker rm -f $(docker ps -aq --filter ancestor=dockerlab/secret-leak:bad) 2>/dev/null || true
docker rmi dockerlab/secret-leak:bad
```

---

## Типовые ошибки

| Ошибка | Последствие | Исправление |
|---|---|---|
| Запуск от root | Root на хосте при escape | `USER app` в Dockerfile |
| Секрет в `ENV`/`ARG` | Виден в `docker history` навсегда | Compose secrets или Vault |
| `read_only: true` без `tmpfs` | Падение приложения при записи в `/tmp` | Добавить `tmpfs: [/tmp]` |
| `cap_drop: ALL` без `no-new-privileges` | setuid-бинарники могут вернуть привилегии | `security_opt: [no-new-privileges:true]` |
| Большой базовый образ | Много CVE, долгий pull | Использовать `-slim` или `-alpine` |

---

## Вопросы для самопроверки

1. Какие capabilities Docker добавляет контейнеру по умолчанию и почему это риск?
2. Почему `ARG SECRET=...` в Dockerfile — утечка, даже если не использовать `ENV`?
3. Что именно даёт `no-new-privileges:true`? Как это проверить?
4. Чем distroless лучше alpine для production и в чём его минус для отладки?
5. Как прочитать секрет из `/run/secrets/` в Python/Go/shell?
6. Trivy нашёл HIGH CVE в базовом образе — что делать, если патча ещё нет?

---

## Cleanup

```bash
./cleanup.sh
```
