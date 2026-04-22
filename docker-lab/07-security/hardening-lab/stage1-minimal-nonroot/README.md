# Этап 1 — минимальная база + non-root

Что изменилось относительно stage0:

| | stage0 | stage1 |
|---|---|---|
| База | ubuntu:latest (~70MB+пакеты) | python:3.12-alpine |
| Пользователь | root | appuser (uid 10001) |
| USER в Dockerfile | нет | `USER appuser` |

Проверка:

```bash
./run.sh
# внутри контейнера: id  →  uid=10001(appuser) gid=10001(appgroup)
```

Что ещё НЕ исправлено — это темы следующих этапов:

- Секрет всё ещё лежит в `ENV` (stage2).
- `read_only`, `cap_drop`, `no-new-privileges`, лимиты — нет (stage3).
- Скан уязвимостей — stage5.
