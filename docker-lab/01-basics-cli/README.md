# 01. CLI база и жизненный цикл контейнера

## Цель

Уверенно работать с контейнером на всём lifecycle: запуск, диагностика,
остановка, удаление, рестарт-политики, коды выхода.

---

## Теория

### Жизненный цикл контейнера

```text
docker run
    │
    ▼
 created ──► running ──► paused
                │              │
                │              ▼
                │           resumed
                │
                ▼
             stopped ──► removed
                │
                ▼
           restarting  (по restart policy)
```

### Ключевые команды

| Команда | Что делает |
|---|---|
| `docker run` | Создаёт и запускает контейнер |
| `docker ps` | Запущенные контейнеры (`-a` — все включая остановленные) |
| `docker logs` | Вывод stdout/stderr контейнера |
| `docker exec` | Запускает команду внутри работающего контейнера |
| `docker inspect` | Полная JSON-информация о контейнере/образе |
| `docker top` | Процессы внутри контейнера (вид со стороны хоста) |
| `docker stats` | Потребление ресурсов в реальном времени |
| `docker events` | Поток событий Docker daemon |
| `docker stop` | SIGTERM → ждёт 10s → SIGKILL |
| `docker kill` | Немедленно посылает указанный сигнал (по умолчанию SIGKILL) |
| `docker rm` | Удаляет остановленный контейнер |

### PID 1: почему это важно

Внутри контейнера первый процесс получает PID 1.
Docker посылает сигналы именно этому процессу.

Если PID 1 — shell-скрипт, он по умолчанию **не форвардит SIGTERM** дочерним
процессам. Приложение не успевает завершиться gracefully → убивается через 10s.

Решение: использовать `dumb-init` или `exec` в скриптах:

```bash
#!/bin/sh
exec python app.py    # exec заменяет shell → Python становится PID 1
```

### docker stop vs docker kill

```bash
docker stop <name>           # SIGTERM → grace period (10s) → SIGKILL
docker stop -t 30 <name>     # увеличить grace period до 30s
docker kill <name>           # немедленный SIGKILL (нет grace period)
docker kill -s SIGHUP <name> # послать конкретный сигнал
```

`docker stop` — правильный способ для graceful shutdown.
`docker kill` — когда контейнер завис и не реагирует на SIGTERM.

### Коды выхода

| Код | Сигнал | Причина |
|---|---|---|
| `0` | — | Нормальное завершение |
| `1` | — | Ошибка приложения |
| `125` | — | Ошибка самого Docker (неверные флаги) |
| `126` | — | Команда найдена, но не может быть выполнена |
| `127` | — | Команда не найдена |
| `130` | SIGINT | Ctrl+C |
| `137` | SIGKILL | OOMKill или `docker kill` |
| `143` | SIGTERM | `docker stop` (graceful) |

```bash
# Посмотреть код выхода последнего запуска
docker inspect <name> --format '{{.State.ExitCode}}'
docker inspect <name> --format '{{.State.OOMKilled}}'
```

### docker events — поток событий

```bash
# Все события в реальном времени
docker events

# События конкретного контейнера
docker events --filter container=cli-nginx

# События за последние 10 минут
docker events --since 10m

# Только события определённого типа
docker events --filter type=container --filter event=die
```

Полезно для диагностики: почему контейнер умер, когда рестартовал,
какой был exit code.

### Restart policies

| Policy | Поведение |
|---|---|
| `no` (default) | Не перезапускать никогда |
| `always` | Всегда, даже после `docker stop` |
| `unless-stopped` | Всегда, кроме ручной остановки |
| `on-failure[:N]` | Только при ненулевом exit code, макс N раз |

```bash
# Изменить политику у работающего контейнера
docker update --restart unless-stopped cli-nginx
```

`--restart always` опасен для сервисов, которые падают из-за неправильного
конфига — создаёт бесконечный crashloop.

---

## Практика

### 1. Запустите nginx

```bash
docker run -d --name cli-nginx -p 8080:80 \
  --restart unless-stopped nginx:1.27-alpine
```

### 2. Проверьте состояние

```bash
docker ps
docker logs cli-nginx --tail 20
docker inspect cli-nginx --format '{{.State.Status}}'
```

### 3. Диагностика внутри контейнера

```bash
docker exec -it cli-nginx sh
# Внутри: ps aux, netstat -tlnp, cat /etc/nginx/nginx.conf
exit
```

### 4. Проверьте процессы и ресурсы

```bash
docker top cli-nginx
docker stats cli-nginx --no-stream
```

### 5. Найдите PID контейнера на хосте

```bash
# PID nginx на хосте (не внутри контейнера)
docker inspect cli-nginx --format '{{.State.Pid}}'

# Убедитесь, что это реальный процесс хоста
ps aux | grep $(docker inspect cli-nginx --format '{{.State.Pid}}')
```

### 6. Понаблюдайте за событиями при остановке

В отдельном терминале запустите:

```bash
docker events --filter container=cli-nginx
```

В основном терминале:

```bash
docker stop cli-nginx
# В терминале событий: kill, die, stop
docker inspect cli-nginx --format 'exit: {{.State.ExitCode}}'
# 0 или 143 (SIGTERM graceful)
```

### 7. Запустите и сразу удалите

```bash
# --rm удаляет контейнер сразу после завершения
docker run --rm alpine echo "hello from alpine"
docker ps -a  # контейнера нет
```

### 8. Остановите и удалите

```bash
docker stop cli-nginx
docker rm cli-nginx
# Или одной командой:
docker rm -f cli-nginx
```

---

## Проверка

- Контейнер доступен на `http://localhost:8080`.
- Умеете получить PID процесса и состояние контейнера через `inspect`.
- Понимаете разницу `docker stop` и `docker kill`.
- Знаете, что означают exit codes 137 и 143.
- Умеете отслеживать события через `docker events`.

---

## Типовые ошибки

| Ошибка | Симптом | Исправление |
|---|---|---|
| Порт 8080 уже занят | `bind: address already in use` | `lsof -i :8080` или сменить порт |
| Перепутан container name и image name | `no such container` | `docker ps` для имён контейнеров |
| Интерактивная команда без `-it` | `exec: input device is not a TTY` | Добавить `-it` |
| `docker rm` на запущенном | `cannot remove running container` | Сначала `docker stop`, или `rm -f` |
| `--restart always` при плохом конфиге | Бесконечный crashloop | Использовать `on-failure:3` |

---

## Вопросы

1. Почему важно, какой процесс является PID 1?
2. Чем `docker stop` отличается от `docker kill`? Когда применять каждый?
3. Что означает exit code 137? Чем он отличается от 143?
4. Когда `--restart always` может быть вреден?
5. Как отследить момент гибели контейнера и его причину?

---

## Дополнительные задания

- Сымитируйте падение процесса (`docker kill -s SIGKILL cli-nginx`)
  и отследите поведение restart policy через `docker events`.
- Запустите контейнер с `--restart on-failure:3` и заставьте его падать —
  посмотрите, когда он перестанет рестартовать.
- Найдите PID контейнера на хосте и посмотрите его namespaces:
  `ls -la /proc/<PID>/ns/`.

---

## Файлы модуля

- `lab/run-nginx.sh` — быстрый сценарий запуска.
- `broken/crashloop.sh` — пример контейнера, который постоянно падает.
- `checks/verify.sh` — автоматическая проверка базовых команд.

## Cleanup

```bash
./cleanup.sh
```
