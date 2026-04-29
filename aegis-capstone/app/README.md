---
title: app/ — микросервисы Aegis Ledger
status: draft
audience: [contributors, llm]
last_verified: 2026-04-29
related:
  - ../docker-compose.yml
  - ../docs/PROJECT_PLAN.md
  - ../docs/runbooks/deploy-services.md
---

# Микросервисы Aegis Ledger (Phase 2 — local stateful tier)

FastAPI-сервисы с реальной бизнес-логикой против локальных PG/Redis (см. [ADR-0007](../docs/adr/0007-local-stateful-in-compose.md)). Все публикуют `/health`, `/ready` (с настоящей проверкой deps), `/metrics`.

| Каталог | Порт | Domain endpoint | Что делает реально |
|---|---|---|---|
| `ledger-api/` | 8081 | `POST /v1/entries` | INSERT в PG `journal_entries`, идемпотентность по `(tenant_id, external_ref)` |
| `matcher/` | 8083 | `POST /v1/expected`, `POST /v1/match` | Регистрация ожиданий в Redis, one-shot match с detection discrepancy |
| `normalizer/` | 8082 | `POST /v1/normalize` | Stub до Phase 2.5 (нужен Kafka + Mongo) |

## Структура каждого сервиса

```
ledger-api/
├── Dockerfile         # python:3.12-alpine + uvicorn
├── requirements.txt   # fastapi, uvicorn, prometheus-client
└── main.py            # FastAPI app (~80 строк)
```

## Локальная разработка одного сервиса

```bash
cd app/ledger-api
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
SERVICE_NAME=ledger-api VERSION=dev uvicorn main:app --reload --port 8081
```

Затем:
```bash
curl http://127.0.0.1:8081/health
curl http://127.0.0.1:8081/metrics
```

## Локальный compose всех трёх

Для прогона прямо на ноутбуке (без az-app):

```bash
docker compose up -d --build
docker compose ps
curl http://127.0.0.1:8081/health
docker compose down
```

## Деплой на az-app

См. [`docs/runbooks/deploy-services.md`](../docs/runbooks/deploy-services.md).

## Что дальше

**Phase 2.5** — `normalizer` подключить к Kafka + Mongo (добавить контейнеры в compose, реальный Kafka producer, MongoDB raw event archive).

**Phase 3** — переложить stateful tier на az-db через WG overlay. Изменение — только env-vars (`POSTGRES_HOST`, `REDIS_HOST`), код приложения не меняется. Подробности — [ADR-0007 §Migration plan](../docs/adr/0007-local-stateful-in-compose.md#migration-plan-phase-3).

**Phase 4** — добавить недостающие сервисы (`ingest-api`, `reconcile-batch-worker`, `report-api`, `alerter`, `archiver`).

## Соглашения

- **Один сервис = одна папка = один Dockerfile**. Не делаем shared/ через build context — пока 3 сервиса по 80 строк, копи-паст быстрее DRY.
- **Версии в env (`VERSION=0.1.0`)** — отображаются в `/health` и Prometheus-метриках.
- **`SERVICE_NAME` обязателен** — попадает в label метрик `service=` (без него метрики разных сервисов сливаются).
- **`/health` = liveness, `/ready` = readiness** — разделение для будущего K8s.
