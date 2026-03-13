# 07. Security и hardening

## Цель

Снизить риск на уровне образа и рантайма: non-root, read-only FS,
минимальные capabilities, отсутствие секретов в слоях, сканирование образов.

---

## Теория

### 1. Non-root пользователь

Большинство официальных образов запускают процесс от `root` по умолчанию.
Это значит, что при побеге из контейнера атакующий получает root на хосте.

```dockerfile
# Alpine-style
RUN addgroup -S app && adduser -S -G app app
USER app

# Debian-style
RUN addgroup --system app && adduser --system --ingroup app app
USER app
```

Проверка:
```bash
docker inspect <container> --format '{{.Config.User}}'
# Должно быть: app (или uid != 0)

docker exec <container> id
# uid=100(app) gid=101(app) — НЕ root
```

### 2. Read-only filesystem + tmpfs

```yaml
services:
  app:
    read_only: true          # корневая ФС только для чтения
    tmpfs:
      - /tmp                 # RAM-диск для временных файлов
      - /var/run             # PID-файлы и сокеты
```

Если приложение пишет в `/tmp` или `/var/run` — это нормально через `tmpfs`.
Всё остальное не должно записывать на диск в production.

Проверка:
```bash
docker inspect <container> --format '{{.HostConfig.ReadonlyRootfs}}'
# true
```

### 3. Capabilities: принцип минимальных привилегий

Linux capabilities разбивают права root на ~40 отдельных привилегий.
По умолчанию Docker оставляет ~14 capabilities. Нужно дропать всё, добавляя только нужное.

```yaml
services:
  app:
    cap_drop:
      - ALL                  # сбрасываем все capabilities
    cap_add:
      - NET_BIND_SERVICE     # разрешаем биндиться на порты < 1024 (если нужно)
```

Частые capabilities и когда они нужны:

| Capability | Нужна для |
|---|---|
| `NET_BIND_SERVICE` | Биндинг на порты < 1024 (nginx, 443) |
| `CHOWN` | Смена владельца файлов в entrypoint |
| `SETUID`/`SETGID` | Su, sudo внутри контейнера |
| `SYS_PTRACE` | strace, gdb (только для отладки!) |

### 4. no-new-privileges

Запрещает процессу повысить привилегии через `setuid`-биты или `sudo`:

```yaml
security_opt:
  - no-new-privileges:true
```

### 5. Секреты: что нельзя и что можно

| Способ | Видимость | Рекомендация |
|---|---|---|
| `ENV` в Dockerfile | `docker history`, любой с доступом к образу | **Никогда** |
| `ARG` в Dockerfile | `docker history --no-trunc` | **Никогда** |
| `environment:` в compose.yaml | git-история, логи | Только для dev |
| `.env` файл (не в git) | только на хосте | Приемлемо для dev |
| `secrets:` в compose | bind-mount `/run/secrets/` | **Рекомендуется** |
| Vault / AWS SSM / переменные CI | внешняя система | Лучший вариант |

**Docker Compose secrets** — монтируют секрет как файл:

```yaml
# compose.yaml
secrets:
  db_password:
    file: ./secrets/db_password.txt   # файл не в git!

services:
  app:
    secrets:
      - db_password
    # секрет доступен как /run/secrets/db_password
```

В приложении читайте из файла, а не из переменной окружения:
```python
with open('/run/secrets/db_password') as f:
    password = f.read().strip()
```

### 6. Сканирование образов — Trivy

[Trivy](https://github.com/aquasecurity/trivy) — сканер CVE, секретов
и мисконфигураций. Запуск без установки через Docker:

```bash
# Сканирование образа на CVE
docker run --rm aquasec/trivy:latest image dockerlab/secure-app:dev

# Только HIGH и CRITICAL уязвимости
docker run --rm aquasec/trivy:latest image \
  --severity HIGH,CRITICAL dockerlab/secure-app:dev

# Сканирование Dockerfile на мисконфигурации
docker run --rm -v "$(pwd)":/work aquasec/trivy:latest config /work/lab

# Сканирование на секреты в файловой системе образа
docker run --rm aquasec/trivy:latest image \
  --scanners secret dockerlab/secure-app:dev
```

Что проверяет Trivy:
- CVE в OS-пакетах и зависимостях (pip, npm, go.sum...)
- Секреты в слоях образа (токены, ключи, пароли)
- Мисконфигурации Dockerfile (root, latest, ADD вместо COPY)

### 7. Минимальный базовый образ

```dockerfile
# Уровни по размеру и attack surface (от большого к малому):
FROM ubuntu:22.04            # ~80 MB, много пакетов
FROM debian:bookworm-slim    # ~50 MB, меньше пакетов
FROM python:3.12-slim        # ~130 MB, slim Debian
FROM python:3.12-alpine      # ~50 MB, musl libc (осторожно с совместимостью)
FROM gcr.io/distroless/python3  # ~30 MB, нет shell вообще
```

Distroless — нет shell, нет менеджера пакетов, нет лишних инструментов.
Отлично для production, сложнее для отладки.

---

## Практика

### 1. Соберите secure-образ

```bash
docker build -t dockerlab/secure-app:dev ./lab
```

### 2. Поднимите стенд

```bash
docker compose -f lab/compose.yaml up -d --build
```

### 3. Проверьте hardening

```bash
# Пользователь не root?
docker inspect security-app --format '{{.Config.User}}'

# Корневая ФС read-only?
docker inspect security-app --format '{{.HostConfig.ReadonlyRootfs}}'

# Capabilities сброшены?
docker inspect security-app \
  --format '{{.HostConfig.CapDrop}}  add: {{.HostConfig.CapAdd}}'
```

### 4. Просканируйте образ через Trivy

```bash
# Все уязвимости
docker run --rm aquasec/trivy:latest image dockerlab/secure-app:dev

# Только критические
docker run --rm aquasec/trivy:latest image \
  --severity HIGH,CRITICAL dockerlab/secure-app:dev
```

### 5. Найдите утечку в broken/Dockerfile.secret

```bash
# Соберите сломанный образ
docker build -t dockerlab/secret-leak:bad ./broken

# Найдите секрет в истории слоёв
docker history dockerlab/secret-leak:bad --no-trunc | grep -i secret

# Сканируем на секреты
docker run --rm aquasec/trivy:latest image \
  --scanners secret dockerlab/secret-leak:bad
```

---

## Проверка

- Контейнер работает от non-root пользователя.
- Корневая ФС read-only (`ReadonlyRootfs: true`).
- `cap_drop: [ALL]` применён.
- `no-new-privileges:true` установлен.
- Trivy не находит HIGH/CRITICAL в финальном образе.
- Понимаете разницу между способами передачи секретов.

---

## Типовые ошибки

| Ошибка | Последствие | Исправление |
|---|---|---|
| Запуск от root | Root на хосте при побеге | `USER app` в Dockerfile |
| Секрет в `ENV`/`ARG` | Виден в `docker history` | Compose secrets или внешняя система |
| Нет `tmpfs` при `read_only` | Приложение падает при записи в `/tmp` | Добавить `tmpfs: [/tmp]` |
| `cap_drop` без `no-new-privileges` | Можно восстановить caps через setuid | Добавить `no-new-privileges:true` |
| Базовый образ с known CVE | Уязвимый runtime | `trivy image` + обновление |

---

## Вопросы

1. Какие возможности теряет контейнер при `cap_drop: ALL`?
2. Почему секрет в `ENV` хуже, чем секрет в файле через Compose secrets?
3. Что даёт `no-new-privileges`? Как его обойти без него?
4. Чем distroless лучше alpine для production? В чём минус?
5. Что именно проверяет Trivy? Какие типы уязвимостей?

---

## Дополнительные задания

- Прогоните `python:3.12` и `python:3.12-slim` через Trivy — сравните количество CVE.
- Добавьте Trivy как шаг в CI (проверьте `.github/workflows/docker-lab-ci.yml`).
- Реализуйте передачу пароля через Compose `secrets:` вместо `environment:`.
- Попробуйте запустить образ без `tmpfs` при включённом `read_only` — что упадёт?

---

## Файлы модуля

- `lab/Dockerfile` — hardened образ (non-root, минимальный base).
- `lab/compose.yaml` — read-only + tmpfs + cap_drop + no-new-privileges.
- `broken/Dockerfile.secret` — секрет в слое образа через ARG/ENV.
- `checks/verify.sh` — автоматическая проверка hardening.

## Cleanup

```bash
./cleanup.sh
```
