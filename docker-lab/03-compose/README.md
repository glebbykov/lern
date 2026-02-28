# 03. Docker Compose

## Цель
Поднять многоконтейнерное приложение (`api + postgres`) с healthcheck и воспроизводимым конфигом.

## Теория
- Важные секции: `services`, `networks`, `volumes`, `depends_on`, `healthcheck`, `profiles`.
- `depends_on` с `condition: service_healthy` уменьшает race condition на старте.
- Всегда проверяйте effective-конфиг: `docker compose config`.

## Практика
1. Соберите и поднимите стенд:
```bash
docker compose -f lab/compose.yaml up -d --build
```
2. Проверьте сервисы:
```bash
docker compose -f lab/compose.yaml ps
curl http://localhost:8081/healthz
```
3. Проверьте подключение к БД через API:
```bash
curl http://localhost:8081/db-check
```
4. Сверьте со `broken/compose.yaml` и найдите, почему он ненадежен.

## Проверка
- API и DB в состоянии `healthy`.
- API отвечает `200` на `/healthz`.
- `/db-check` возвращает `ok`.

## Типовые ошибки
- Неверные env-переменные БД.
- Отсутствие healthcheck или неверный `depends_on`.
- Конфликт порта 8081.

## Вопросы
1. Почему `depends_on` без healthcheck не гарантирует готовность?
2. Что полезнее для отладки: `logs -f` или `events`?
3. Как разделить dev/prod через профили?

## Дополнительные задания
- Добавьте профиль `debug` с инструментальным контейнером.
- Вынесите переменные в `.env`.

## Cleanup
```bash
./cleanup.sh
```
