# Этап 2 — управление секретами (правило 5)

Секрет больше не:
- запекается в `ENV` Dockerfile,
- не виден в `docker image inspect`,
- не виден в `docker history`.

Секрет приезжает **в рантайме** через Compose secrets и лежит в
`/run/secrets/app_secret` — это tmpfs-маунт, доступный только для
чтения процессу приложения. Код читает файл один раз на старте.

## Запуск

```bash
./run.sh
# /secret должен вернуть { "source": "file", ... }
```

## На что смотреть

- `docker image inspect ... --format '{{.Config.Env}}'` — пусто/без секрета.
- `docker exec ... env | grep SECRET` — ничего.
- `docker exec ... cat /run/secrets/app_secret` — виден только процессам
  внутри контейнера, на хост ничего не экспортировано.
