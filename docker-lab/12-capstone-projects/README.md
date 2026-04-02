# 12. Capstone проекты

## Цель

Собрать end-to-end проект, который применяет всё из модулей 01–11: build, networking, storage, security, observability, release flow.

---

## Как работать с капстоуном

1. Выбери трек (ниже).
2. Прочитай `spec.md` выбранного трека — там acceptance criteria.
3. Создай рабочую директорию: `lab/<трек>/solution/`.
4. Реализуй `compose.yaml`, `Dockerfile`, скрипты.
5. Проверь себя по чеклисту.

---

## Трек 1 — Web + DB + Cache

**Файл:** [lab/web-db-cache/spec.md](lab/web-db-cache/spec.md)

**Стек:** API сервис + PostgreSQL + Redis + миграции + мониторинг

**Минимальная архитектура:**

```text
[client] → [api :8080] → [postgres :5432]
                       → [redis :6379]
[prometheus] ← [cadvisor]
```

**Быстрый старт — базовый compose.yaml:**

```yaml
services:
  api:
    build: .
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://appuser:apppass@db:5432/appdb
      REDIS_URL: redis://cache:6379
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_started
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 10s
      retries: 3

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: apppass
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d appdb"]
      interval: 5s
      retries: 5

  cache:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  pg_data:
  redis_data:
```

**Acceptance criteria:**
- [ ] `docker compose up -d` поднимает весь стек за одну команду
- [ ] `/healthz` и `/readyz` отвечают корректно
- [ ] Данные переживают `docker compose restart` (volume)
- [ ] Миграции схемы БД применяются при старте
- [ ] Resource limits выставлены для всех сервисов
- [ ] Log rotation включена
- [ ] Есть backup/restore скрипт для БД

---

## Трек 2 — Security-first

**Файл:** [lab/security-first/spec.md](lab/security-first/spec.md)

**Задача:** Собрать сервис с максимально hardened конфигурацией

**Чеклист hardening:**

```bash
# 1. Non-root
docker inspect <container> --format '{{.Config.User}}'
# Ожидается: app (не root и не пусто)

# 2. Read-only rootfs
docker inspect <container> --format '{{.HostConfig.ReadonlyRootfs}}'
# Ожидается: true

# 3. Capabilities
docker inspect <container> --format '{{.HostConfig.CapDrop}}'
# Ожидается: [ALL]

# 4. no-new-privileges
docker inspect <container> --format '{{.HostConfig.SecurityOpt}}'
# Ожидается: [no-new-privileges:true]

# 5. Нет секретов в ENV
docker inspect <container> --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | grep -iE 'password|token|secret|key' || echo 'OK: no secrets in env'

# 6. Trivy: нет HIGH/CRITICAL
docker run --rm aquasec/trivy:latest image --severity HIGH,CRITICAL <image>

# 7. Теги без latest
grep -r 'image:.*:latest' compose.yaml && echo 'FAIL' || echo 'OK'
```

**Acceptance criteria:**
- [ ] Все 7 пунктов выше прошли
- [ ] Секреты передаются через Compose `secrets:` или файл
- [ ] Релизный тег — semver, без `latest`
- [ ] Есть `checks/verify.sh` автоматизирующий проверку

---

## Трек 3 — Event-driven

**Файл:** [lab/event-driven/spec.md](lab/event-driven/spec.md)

**Стек:** Producer → RabbitMQ/Redis Streams → Consumer + Dead Letter Queue

**Базовая архитектура:**

```yaml
services:
  producer:
    build: ./producer
    environment:
      BROKER_URL: redis://broker:6379
    depends_on:
      - broker

  consumer:
    build: ./consumer
    environment:
      BROKER_URL: redis://broker:6379
    depends_on:
      - broker

  broker:
    image: redis:7-alpine
    volumes:
      - broker_data:/data

volumes:
  broker_data:
```

**Acceptance criteria:**
- [ ] Producer публикует сообщения, Consumer обрабатывает
- [ ] При падении Consumer — сообщения не теряются (persistence)
- [ ] Реализована retry-логика (min 3 попытки)
- [ ] Реализована Dead Letter Queue для необработанных сообщений
- [ ] Метрики: количество обработанных / в очереди / в DLQ

---

## Общий чеклист для всех треков

| Критерий | Обязательно |
|---|---|
| Одна команда для старта | `docker compose up -d` |
| Health endpoints | `/healthz`, `/readyz` |
| Resource limits | Все сервисы |
| Log rotation | `max-size`, `max-file` |
| Persistent storage | Named volumes, не anonymous |
| Security controls | Non-root, cap_drop |
| Release tag | Semver, без `:latest` |
| Cleanup | `docker compose down -v` |
| Автопроверка | `checks/verify.sh` |

---

## Структура solution-директории

```text
lab/<трек>/solution/
├── compose.yaml          # основной стек
├── Dockerfile            # если нужен custom образ
├── Makefile              # up, down, test, verify
├── checks/
│   └── verify.sh         # автоматическая проверка
└── README.md             # описание решения
```

**Минимальный Makefile:**

```bash
# Makefile targets (tabs обязательны в настоящем Makefile)
# up:      docker compose up -d
# down:    docker compose down -v
# test:    curl -f http://localhost:8080/healthz
# verify:  ./checks/verify.sh

make up
make test
make verify
make down
```

---

## Типичные ошибки

**Из `broken/common-failures.md`:**

- Нет `depends_on` с `condition: service_healthy` → API стартует до БД
- Нет volume у БД → данные теряются при `docker compose down`
- `image:latest` в compose → неизвестно что задеплоено
- Нет `max-size` в logging → диск заполняется
- Секрет в `environment:` → утечка в логи CI

---

## Cleanup

```bash
./cleanup.sh
```
