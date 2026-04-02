# Troubleshooting Checklist

## Шаг 1 — Зафиксировать симптом

- Что именно не работает? (не стартует / падает / не отвечает / тормозит)
- Когда началось? Что изменилось перед инцидентом?

## Шаг 2 — Состояние контейнеров

```bash
docker ps -a                          # статус, ExitCode, время последнего запуска
docker compose ps                     # состояние сервисов проекта
```

## Шаг 3 — Логи

```bash
docker logs --tail 200 <id>
docker logs --since 10m <id>
docker compose logs -f --tail 100
```

## Шаг 4 — Inspect: факты о контейнере

```bash
docker inspect <id> --format '{{.State.ExitCode}}'
docker inspect <id> --format '{{.State.OOMKilled}}'
docker inspect <id> --format '{{.State.Error}}'
docker inspect <id> --format '{{json .State.Health}}'
docker inspect <id> --format '{{json .Config.Env}}'
docker inspect <id> --format '{{json .Mounts}}'
docker inspect <id> --format '{{json .NetworkSettings.Networks}}'
docker inspect <id> --format '{{.HostConfig.Memory}}'
docker inspect <id> --format '{{.HostConfig.ReadonlyRootfs}}'
```

## Шаг 5 — Хронология событий

```bash
docker events --since 10m
docker events --since 10m --filter event=die
docker events --since 10m --filter container=<name>
```

## Шаг 6 — Ресурсы

```bash
docker stats --no-stream
docker system df
```

## Шаг 7 — Внутри контейнера (если запущен)

```bash
docker exec <id> env | sort
docker exec <id> ss -tulnp
docker exec <id> df -h
docker exec -it <id> sh
```

## Шаг 8 — Сеть

```bash
docker network ls
docker network inspect <net>
docker exec <id> nslookup <service>.
docker exec <id> nc -zw2 <host> <port>
```

## Шаг 9 — Fix и проверка

- Минимальное изменение, которое устраняет root cause
- Проверить что сервис стартовал и работает корректно
- Задокументировать: симптом → причина → fix

## Коды выхода — шпаргалка

| Код | Причина |
|---|---|
| `0` | Успех |
| `1` | Ошибка приложения |
| `2` | Misuse of shell / нет переменной (`set -u`) |
| `125` | Docker daemon error |
| `126` | Команда не исполняема |
| `127` | Команда не найдена |
| `137` | SIGKILL — OOM kill или `docker kill` |
| `143` | SIGTERM — `docker stop` |
