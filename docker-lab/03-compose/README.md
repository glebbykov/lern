# 03. Docker Compose

## Цель

Поднять многоконтейнерное приложение (`api + postgres`) с healthcheck
и воспроизводимым конфигом. Понять `.env`, profiles и override-файлы.

---

## Теория

### Структура compose.yaml

```yaml
services:       # контейнеры
networks:       # пользовательские сети
volumes:        # именованные тома
configs:        # конфигурационные файлы
secrets:        # секреты (Swarm / Compose v2)
```

### depends_on: почему condition: service_healthy критически важен

```yaml
# ❌ Плохо: api стартует сразу, postgres ещё не готов к соединениям
api:
  depends_on:
    - db

# ✅ Хорошо: api ждёт пока db не ответит на healthcheck
api:
  depends_on:
    db:
      condition: service_healthy
```

Без `condition: service_healthy` `depends_on` гарантирует только порядок
**запуска**, но не готовность сервиса.

### .env файл — переменные по умолчанию

Compose автоматически загружает `.env` из директории проекта:

```dotenv
# lab/.env
POSTGRES_USER=appuser
POSTGRES_PASSWORD=secret
POSTGRES_DB=appdb
APP_PORT=8081
```

В `compose.yaml` используйте переменные:
```yaml
services:
  db:
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
  api:
    ports:
      - "${APP_PORT}:8081"
```

Проверить подстановку:
```bash
docker compose config          # показывает итоговый конфиг с раскрытыми переменными
docker compose config --quiet  # только вывод ошибок, полезно в CI
```

### Profiles — опциональные сервисы

```yaml
services:
  api:
    # без profiles — всегда запускается
    image: myapp:dev

  db:
    image: postgres:16-alpine

  adminer:
    image: adminer:4
    profiles: [debug]         # запускается только при --profile debug
    ports:
      - "8080:8080"

  tests:
    image: myapp:dev
    profiles: [test]
    command: pytest
```

```bash
# Только обязательные сервисы:
docker compose up -d

# С debug-инструментами:
docker compose --profile debug up -d

# Запустить тесты:
docker compose --profile test run --rm tests
```

### Override файлы — dev vs prod

```text
compose.yaml           ← базовый конфиг (production)
compose.override.yaml  ← автозагружается поверх, для dev
compose.prod.yaml      ← явный override для production
```

```yaml
# compose.yaml (base)
services:
  api:
    image: registry/myapp:1.0.0
    restart: unless-stopped

# compose.override.yaml (dev — автозагружается)
services:
  api:
    build: .              # пересобираем локально
    volumes:
      - .:/app            # hot reload
    environment:
      DEBUG: "true"
```

```bash
# Dev (автоматически объединяет compose.yaml + compose.override.yaml):
docker compose up -d

# Production (только base + явный override):
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

### Полезные команды диагностики

```bash
docker compose ps                      # состояние всех сервисов
docker compose logs -f api             # потоковые логи конкретного сервиса
docker compose logs --tail=50          # последние 50 строк всех сервисов
docker compose exec api sh             # зайти внутрь сервиса
docker compose top                     # процессы во всех контейнерах
docker compose events                  # события в реальном времени
docker compose port api 8081           # узнать публичный порт
docker compose config                  # итоговый конфиг с раскрытыми переменными
```

---

## Практика

### 1. Создайте .env файл

```bash
cat > lab/.env << 'EOF'
POSTGRES_USER=appuser
POSTGRES_PASSWORD=secret
POSTGRES_DB=appdb
EOF
```

### 2. Соберите и поднимите стенд

```bash
docker compose -f lab/compose.yaml up -d --build
```

### 3. Проверьте сервисы

```bash
docker compose -f lab/compose.yaml ps
curl http://localhost:8081/healthz
```

### 4. Проверьте подключение к БД через API

```bash
curl http://localhost:8081/db-check
```

### 5. Проверьте итоговый конфиг с раскрытыми переменными

```bash
docker compose -f lab/compose.yaml config
```

### 6. Найдите проблему в broken/compose.yaml

```bash
# Попробуйте поднять сломанный стенд:
docker compose -f broken/compose.yaml up -d
docker compose -f broken/compose.yaml logs
# Что не так? Проверьте: healthcheck, depends_on, переменные окружения
```

---

## Проверка

- API и DB в состоянии `healthy` (`docker compose ps`).
- API отвечает `200` на `/healthz`.
- `/db-check` возвращает `ok`.
- Понимаете, что выводит `docker compose config`.
- Можете объяснить, зачем нужен `.env` и `condition: service_healthy`.

---

## Типовые ошибки

| Ошибка | Симптом | Исправление |
|--------|---------|-------------|
| `depends_on` без `condition` | API падает при старте, нет соединения с DB | Добавить `condition: service_healthy` |
| Нет healthcheck у DB | `condition: service_healthy` зависает | Добавить `healthcheck` к postgres |
| Неверные env-переменные БД | Connection refused / auth failed | Сверить `POSTGRES_USER/PASSWORD/DB` |
| Конфликт порта 8081 | `bind: address already in use` | `lsof -i :8081` или сменить порт в `.env` |
| Секреты в `compose.yaml` | Утечка в git | Вынести в `.env`, добавить `.env` в `.gitignore` |

---

## Вопросы

1. Почему `depends_on` без healthcheck не гарантирует готовность?
2. Что полезнее для отладки: `logs -f` или `events`?
3. Как разделить dev/prod через profiles или override-файлы?
4. Что произойдёт если `.env` не существует — compose упадёт или нет?
5. Как узнать, какие переменные подставились в итоге?

---

## Дополнительные задания

- Добавьте профиль `debug` с `adminer` для визуального управления Postgres.
- Вынесите все секреты в `.env` и убедитесь, что он в `.gitignore`.
- Создайте `compose.override.yaml` для dev: добавьте bind-mount кода.
- Напишите healthcheck для API на `/healthz`.

---

## Файлы модуля

- `lab/compose.yaml` — рабочий стенд (api + postgres).
- `lab/.env` — переменные окружения (создайте сами по инструкции выше).
- `broken/compose.yaml` — намеренно сломанный конфиг.
- `checks/verify.sh` — автоматическая проверка.

## Cleanup

```bash
./cleanup.sh
```
