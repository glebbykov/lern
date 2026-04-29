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

# Микросервисы Aegis Ledger (Phase 1 skeleton)

Минимальные FastAPI-скелеты для трёх сервисов первого приближения. Все три — копия одного шаблона: общий `/health`, `/ready`, `/metrics` + один domain-specific endpoint каждого.

| Каталог | Сервис | Порт | Domain endpoint |
|---|---|---|---|
| `ledger-api/` | приём ledger entries (двойная запись — Phase 2) | 8081 | `POST /v1/entries` |
| `normalizer/` | нормализация feed'ов (Phase 2 — реальный парсинг ISO 20022/CSV/...) | 8082 | `POST /v1/normalize` |
| `matcher/` | сверка transactions (Phase 2 — реальный lookup через Redis/etcd) | 8083 | `POST /v1/match` |

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

## Phase 2 — что добавить

Каждый сервис должен:
1. Подключиться к своим dependencies через WireGuard overlay (см. таблицу в [`docs/PROJECT_PLAN.md`](../docs/PROJECT_PLAN.md#3-сервисы-и-маппинг-на-инфраструктуру)).
2. Вернуть в `/ready` реальный статус коннектов вместо `"skipped"`.
3. Заменить stub-логику `POST /v1/*` на доменное поведение.

## Соглашения

- **Один сервис = одна папка = один Dockerfile**. Не делаем shared/ через build context — пока 3 сервиса по 80 строк, копи-паст быстрее DRY.
- **Версии в env (`VERSION=0.1.0`)** — отображаются в `/health` и Prometheus-метриках.
- **`SERVICE_NAME` обязателен** — попадает в label метрик `service=` (без него метрики разных сервисов сливаются).
- **`/health` = liveness, `/ready` = readiness** — разделение для будущего K8s.
