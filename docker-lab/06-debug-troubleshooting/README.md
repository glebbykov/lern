# 06. Debug и troubleshooting

## Методология

Не угадывать — диагностировать. Каждая проблема решается по одной схеме:

```text
Симптом → Факты (логи/inspect/events) → Гипотеза → Минимальный тест → Fix → Проверка
```

## Инструментарий

```bash
# Состояние контейнеров
docker ps -a                                   # все контейнеры со статусом
docker compose ps                              # состояние сервисов compose-проекта

# Логи
docker logs <id>                               # stdout/stderr контейнера
docker logs --tail 50 --follow <id>            # последние 50 строк, live
docker logs --since 5m <id>                   # только за последние 5 минут
docker compose logs -f --tail 100             # логи всего проекта

# Инспект
docker inspect <id>                            # всё: сеть, volumes, state, env
docker inspect <id> --format '{{.State}}'     # только блок State
docker inspect <id> --format '{{.State.ExitCode}}'
docker inspect <id> --format '{{.State.OOMKilled}}'
docker inspect <id> --format '{{json .HostConfig.Memory}}'

# События
docker events --since 10m                     # системные события Docker за 10 минут
docker events --filter container=<name>       # события конкретного контейнера

# Ресурсы
docker stats                                   # live CPU/MEM/NET/IO всех контейнеров
docker stats --no-stream                       # снимок без live-режима

# Внутри контейнера
docker exec -it <id> sh                       # войти в работающий контейнер
docker exec <id> cat /etc/hosts               # выполнить команду без входа
docker exec <id> env                          # переменные окружения внутри

# Диск
docker system df                               # сколько места занимают images/containers/volumes
docker system df -v                            # детально
```

### Коды выхода

| Код | Причина | Типичный сценарий |
|---|---|---|
| `0` | Успешно | Контейнер завершил задачу |
| `1` | Ошибка приложения | Баг в коде, не найден файл |
| `2` | Misuse of shell | Неверный аргумент bash |
| `125` | Docker daemon error | Нет прав, неверные флаги |
| `126` | Команда не исполняема | chmod не дали, нет x-бита |
| `127` | Команда не найдена | Опечатка в CMD/ENTRYPOINT |
| `137` | SIGKILL (128+9) | OOM killer или `docker kill` |
| `139` | SIGSEGV (128+11) | Segfault в приложении |
| `143` | SIGTERM (128+15) | Graceful stop: `docker stop` |

---

## Сценарий 1 — CrashLoop: контейнер постоянно перезапускается

**Симптом:** `docker ps` показывает статус `Restarting (1) X seconds ago`

```bash
docker compose -f broken/compose-crashloop.yaml up -d
docker ps   # статус: Restarting
```

**Диагностика:**

```bash
# Сколько раз перезапустился?
docker inspect dbg-crash --format '{{.State.RestartCount}}'

# Последний exit code
docker inspect dbg-crash --format '{{.State.ExitCode}}'
# ExitCode: 1 → приложение завершилось с ошибкой

# Посмотреть что произошло
docker logs dbg-crash
# start
# (потом снова start — в бесконечном цикле)
```

**Root cause:** `command: exit 1` + `restart: always` = бесконечный цикл перезапусков.

**Fix:** исправить команду чтобы она не падала, либо убрать `restart: always` на время отладки.

```bash
# Проверить что было бы при правильной команде
docker run --rm alpine:3.20 sh -c "echo ok && exit 0"
# exit code: 0 — контейнер завершился успешно, перезапуска нет

docker compose -f broken/compose-crashloop.yaml down
```

---

## Сценарий 2 — Конфликт портов

**Симптом:** `Error response from daemon: driver failed programming external connectivity`

```bash
docker compose -f broken/compose-port-conflict.yaml up -d
# Error: port 8099 already allocated (два сервиса претендуют на один порт)
```

**Диагностика:**

```bash
# Что уже слушает порт 8099 на хосте?
# Linux:
ss -tulnp | grep 8099
# Windows/Mac:
netstat -ano | grep 8099

# Какой контейнер занял порт?
docker ps --format '{{.Ports}}' | grep 8099

# Посмотреть события
docker events --since 2m --filter event=start
```

**Root cause:** `app1` и `app2` оба объявляют `ports: "8099:80"` — хостовый порт можно слушать только одному процессу.

**Fix:** назначить каждому сервису уникальный порт (`8099:80` и `8100:80`).

```bash
docker compose -f broken/compose-port-conflict.yaml down
```

---

## Сценарий 3 — DNS: сервис не резолвится

**Симптом:** `nslookup api` возвращает `NXDOMAIN` или `connection refused`

```bash
docker compose -f broken/compose-dns.yaml up -d

# client пытается достучаться до api
docker compose -f broken/compose-dns.yaml exec client \
  sh -c "nslookup api. || echo 'DNS fail'"
# server can't find api: NXDOMAIN
```

**Диагностика:**

```bash
# Какие сети у client?
docker inspect $(docker compose -f broken/compose-dns.yaml ps -q client) \
  --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool

# Какие сети у api?
docker inspect $(docker compose -f broken/compose-dns.yaml ps -q api) \
  --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool

# Обе сети проекта
docker network ls | grep dns
```

**Root cause:** `client` в сети `frontend`, `api` в сети `backend` — Docker DNS работает только в пределах одной сети.

**Fix:** добавить `client` в `backend` сеть, или `api` в `frontend`, или объединить через общую сеть.

```bash
docker compose -f broken/compose-dns.yaml down
```

---

## Сценарий 4 — OOM Kill: контейнер убит ядром

**Симптом:** контейнер внезапно останавливается, exit code `137`

```bash
docker compose -f broken/compose-oom.yaml up -d
# Подождать 5-10 секунд
docker ps -a   # статус: Exited (137)
```

**Диагностика:**

```bash
# Exit code 137 = SIGKILL (128 + 9) — убит принудительно
docker inspect dbg-oom --format '{{.State.ExitCode}}'
# 137

# Убит ли OOM killer'ом?
docker inspect dbg-oom --format '{{.State.OOMKilled}}'
# true

# Сколько памяти было разрешено?
docker inspect dbg-oom --format '{{.HostConfig.Memory}}'
# 6291456 = 6 MiB — критически мало

# Логи до момента убийства
docker logs dbg-oom
```

**Root cause:** лимит памяти 6 MiB слишком мал для процесса, Linux OOM killer отправил SIGKILL.

**Fix:** увеличить `mem_limit` / `memory:` до реального потребления приложения. Узнать реальное потребление через `docker stats`.

```bash
# Посмотреть потребление памяти похожего контейнера без лимита
docker run --rm -d --name mem-check alpine:3.20 sh -c "dd if=/dev/zero bs=1M count=20 of=/tmp/x; sleep 30"
docker stats --no-stream mem-check
docker rm -f mem-check

docker compose -f broken/compose-oom.yaml down
```

---

## Сценарий 5 — Healthcheck fail: сервис unhealthy

**Симптом:** `docker ps` показывает `(unhealthy)`, зависимые сервисы не стартуют

```bash
docker compose -f broken/compose-healthcheck-fail.yaml up -d
sleep 15
docker ps   # (unhealthy)
```

**Диагностика:**

```bash
# Детали healthcheck: последние результаты
docker inspect dbg-unhealthy \
  --format '{{json .State.Health}}' | python3 -m json.tool
# "Status": "unhealthy"
# "Log": [{"ExitCode": 1, "Output": "..."}]

# Последние 5 результатов проверки
docker inspect dbg-unhealthy \
  --format '{{range .State.Health.Log}}Exit:{{.ExitCode}} {{.Output}}{{println}}{{end}}'

# Выполнить healthcheck вручную
docker exec dbg-unhealthy wget -qO- http://localhost/healthz
# 404 Not Found — эндпоинт не существует
```

**Root cause:** healthcheck проверяет `/healthz`, которого нет в дефолтном nginx — возвращает 404, wget завершается с ошибкой.

**Fix:** исправить путь healthcheck на `/` или добавить реальный health endpoint в конфиг nginx.

```bash
# Правильная проверка nginx
docker run --rm nginx:1.27-alpine wget -qO- http://localhost/
# HTML-страница — /  работает

docker compose -f broken/compose-healthcheck-fail.yaml down
```

---

## Сценарий 6 — Read-only filesystem: ошибка записи

**Симптом:** `Read-only file system` в логах, контейнер падает или не работает

```bash
docker compose -f broken/compose-readonly-fs.yaml up -d
docker logs dbg-readonly
# sh: can't create /app/data.txt: Read-only file system
# exit code: 1
```

**Диагностика:**

```bash
# Проверить флаг read_only в конфигурации
docker inspect dbg-readonly --format '{{.HostConfig.ReadonlyRootfs}}'
# true

# Посмотреть что примонтировано и с какими правами
docker inspect dbg-readonly --format '{{json .Mounts}}' | python3 -m json.tool

# Список доступных для записи директорий (tmpfs)
docker inspect dbg-readonly --format '{{json .HostConfig.Tmpfs}}'
```

**Root cause:** `read_only: true` делает корневую ФС контейнера read-only. Приложение пытается писать в `/app` — отказ.

**Fix:** либо убрать `read_only: true`, либо добавить `tmpfs` для директорий, куда нужна запись.

```bash
# Правильный подход: read_only + tmpfs для /tmp и /app
# tmpfs:
#   - /tmp
#   - /app

docker compose -f broken/compose-readonly-fs.yaml down
```

---

## Сценарий 7 — Отсутствует переменная окружения

**Симптом:** контейнер падает сразу со странной ошибкой или с `exit 1`/`exit 2`

```bash
docker compose -f broken/compose-missing-env.yaml up -d
docker logs dbg-missing-env
# /entrypoint.sh: DATABASE_URL: parameter not set
# exit code: 2
```

**Диагностика:**

```bash
# Какие переменные есть внутри контейнера?
docker exec dbg-missing-env env | sort
# DATABASE_URL отсутствует

# Или через inspect
docker inspect dbg-missing-env --format '{{json .Config.Env}}' | python3 -m json.tool

# Что передал compose.yaml?
# (читаем файл и ищем environment:)
grep -A 10 environment broken/compose-missing-env.yaml
```

**Root cause:** скрипт использует `set -u` (нельзя обращаться к неустановленным переменным), а `DATABASE_URL` не передана в контейнер.

**Fix:** добавить `environment:` секцию в compose.yaml или файл `.env`.

```bash
# Проверить что переменная видна
docker run --rm -e DATABASE_URL=postgres://localhost/app alpine:3.20 \
  sh -c "echo DB is: $DATABASE_URL"

docker compose -f broken/compose-missing-env.yaml down
```

---

## Сценарий 8 — Неверный образ: ErrImagePull

**Симптом:** `docker compose up` не стартует, статус `ErrImagePull` / `ImagePullBackOff`

```bash
docker compose -f broken/compose-wrong-image.yaml up -d
# Error response from daemon: manifest for nginx:nonexistent-9999 not found
```

**Диагностика:**

```bash
# Посмотреть статус контейнеров
docker compose -f broken/compose-wrong-image.yaml ps

# Событие pull failure
docker events --since 2m --filter event=pull

# Проверить, существует ли тег
docker manifest inspect nginx:nonexistent-9999
# Error: no such manifest

# Найти реальные теги образа
docker search nginx --limit 5
# или открыть hub.docker.com/r/library/nginx/tags
```

**Root cause:** тег `nginx:nonexistent-9999` не существует в Docker Hub.

**Fix:** исправить тег на актуальный: `nginx:1.27-alpine`, `nginx:latest`, etc.

```bash
# Проверить что правильный тег пуллится
docker pull nginx:1.27-alpine

docker compose -f broken/compose-wrong-image.yaml down
```

---

## Сценарий 9 — Volume permissions: Permission denied

**Симптом:** `Permission denied` при попытке записи в volume

```bash
docker compose -f broken/compose-volume-perm.yaml up -d
docker logs dbg-vol-perm
# touch: /data/app.lock: Permission denied
```

**Диагностика:**

```bash
# От чьего имени работает контейнер?
docker inspect dbg-vol-perm --format '{{.Config.User}}'
# 1000 (непривилегированный пользователь)

# Какие права на директорию volume?
docker run --rm -v 06-debug-troubleshooting_vol-perm-data:/data alpine:3.20 ls -lan /data
# drwxr-x--- 2 root root — владелец root, группа root
# UID 1000 не имеет прав на запись

# Посмотреть маунты
docker inspect dbg-vol-perm --format '{{json .Mounts}}' | python3 -m json.tool
```

**Root cause:** volume инициализирован с правами `root:root 750`, контейнер запущен от `user: "1000:1000"` — нет прав на запись.

**Fix:** либо сделать `chown` в entrypoint (от root), либо инициализировать volume с нужным владельцем, либо изменить права через init-контейнер.

```bash
# Правильный подход: init-контейнер меняет права перед стартом приложения
# init:
#   image: alpine:3.20
#   command: ["chown", "-R", "1000:1000", "/data"]
#   volumes: [vol-perm-data:/data]

docker compose -f broken/compose-volume-perm.yaml down -v
```

---

## Сценарий 10 — Контейнер стартует, но не отвечает

**Симптом:** `docker ps` показывает `Up`, но `curl` висит или отдаёт connection refused

```bash
# Пример: nginx запущен, но слушает не на том адресе
docker run -d --name dbg-listen nginx:1.27-alpine
docker inspect dbg-listen --format '{{json .NetworkSettings.Ports}}'
# {} — порты не опубликованы, хотя EXPOSE 80 есть в образе
```

**Диагностика:**

```bash
# 1. Опубликован ли порт? (0.0.0.0:PORT)
docker ps --format 'table {{.Names}}\t{{.Ports}}'

# 2. Что слушает внутри контейнера?
docker exec dbg-listen ss -tulnp
# tcp LISTEN 0 511 0.0.0.0:80

# 3. Сеть контейнера — его IP
docker inspect dbg-listen --format '{{.NetworkSettings.IPAddress}}'
# 172.17.0.X — можно постучать напрямую (только с хоста Linux)

# 4. Проверить доступность напрямую по IP контейнера
curl http://172.17.0.X:80

# 5. Events — не было ли ошибок при старте?
docker events --since 5m --filter container=dbg-listen
```

**Root cause:** `EXPOSE` не публикует порт на хост, нужен `-p 8080:80` / `ports:` в compose.

```bash
docker rm -f dbg-listen
```

---

## Сценарий 11 — Контейнер зависает: как войти и исследовать

Если контейнер запущен, но ведёт себя неожиданно — войди внутрь:

```bash
# Войти в работающий контейнер (если есть sh/bash)
docker exec -it <container_id> sh

# Внутри: проверить процессы
ps aux

# Сетевые соединения
ss -tulnp
netstat -tulnp

# Открытые файлы
ls -la /proc/1/fd

# Доступные переменные окружения
env | sort

# Конфигурационные файлы
cat /etc/nginx/conf.d/default.conf

# Свободное место на ФС
df -h

# Выйти
exit
```

```bash
# Если sh нет (distroless/scratch образ) — использовать nsenter или debug-контейнер
docker run -it --rm \
  --pid=container:<container_id> \
  --network=container:<container_id> \
  --cap-add SYS_PTRACE \
  nicolaka/netshoot
```

---

## Сценарий 12 — docker events: хронология инцидента

`docker events` — журнал событий демона Docker. Незаменим для понимания что и когда произошло.

```bash
# Все события за последние 10 минут
docker events --since 10m

# Только события контейнеров (старт/стоп/die/kill/oom)
docker events --since 10m --filter type=container

# Отфильтровать только смерть контейнеров
docker events --since 10m --filter event=die

# Форматированный вывод
docker events --since 10m \
  --format '{{.Time}} {{.Type}} {{.Action}} {{.Actor.Attributes.name}}'

# Пример: поднять crashloop и наблюдать события в реальном времени
docker compose -f broken/compose-crashloop.yaml up -d
docker events --filter container=dbg-crash &
# через 10 секунд остановить
docker compose -f broken/compose-crashloop.yaml down
kill %1
```

---

## Сценарий 13 — docker stats: мониторинг ресурсов

```bash
# Live мониторинг всех контейнеров
docker stats

# Снимок (без live-обновления)
docker stats --no-stream

# Только нужные колонки
docker stats --no-stream \
  --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'

# Следить за конкретным контейнером
docker stats <container_name>

# Для postgres: сколько памяти реально нужно?
docker run -d --name pg-test postgres:16-alpine \
  -e POSTGRES_PASSWORD=pass
sleep 5
docker stats --no-stream pg-test
# CONTAINER   CPU %   MEM USAGE / LIMIT   MEM %
# pg-test     0.2%    28MiB / 7.7GiB      0.36%
# → минимальный лимит: 64-128 MiB
docker rm -f pg-test
```

---

## Troubleshooting checklist (быстрый алгоритм)

```text
1. docker ps -a                     → статус, ExitCode, время последнего старта
2. docker logs --tail 100 <id>      → что написало приложение
3. docker inspect <id>              → State (ExitCode, OOMKilled, Error), Mounts, Env
4. docker events --since 10m        → хронология событий
5. docker stats --no-stream         → ресурсы (память, CPU)
6. docker exec <id> env             → переменные окружения внутри
7. docker exec <id> ss -tulnp       → что слушает
8. docker network inspect <net>     → кто в какой сети
9. docker system df                 → место на диске
```

---

## Самостоятельные задания

### Задание 1

Запусти `broken/compose-crashloop.yaml`, найди причину и исправь compose так, чтобы контейнер стартовал и оставался в статусе `Up`.

### Задание 2

Запусти `broken/compose-oom.yaml`. Найди через `docker inspect` лимит памяти и факт OOM kill. Увеличь лимит так, чтобы контейнер отработал успешно.

### Задание 3

Запусти `broken/compose-healthcheck-fail.yaml`. Через `docker inspect` найди что именно возвращает healthcheck. Исправь путь проверки.

### Задание 4

Запусти `broken/compose-missing-env.yaml`. Определи какая переменная не передана. Добавь её через `environment:` в compose.yaml.

### Задание 5

Запусти `broken/compose-volume-perm.yaml`. Через `docker inspect` выясни UID процесса и права директории. Придумай два разных способа исправления.

### Задание 6 (сложное)

Запусти любой сломанный сценарий. Не читая README, используй только `docker events`, `docker inspect` и `docker logs` — восстанови полную хронологию инцидента и сформулируй root cause в одном предложении.

---

## Вопросы для самопроверки

1. Что означает exit code `137` и как отличить OOM kill от `docker kill`?
2. Чем опасен `restart: always` без исправления реальной причины падения?
3. Какой командой узнать, был ли контейнер убит OOM killer'ом?
4. Почему `EXPOSE` не делает сервис доступным с хоста?
5. Контейнер `Up`, healthcheck `unhealthy` — зависимые сервисы стартуют?
6. Как войти в контейнер без `sh`/`bash` (distroless образ)?
7. Что показывает `docker events` и чем оно полезнее `docker logs`?
8. Как узнать реальное потребление памяти контейнером перед выставлением лимита?

---

## Cleanup

```bash
./cleanup.sh
```
