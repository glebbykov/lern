---
title: ADR-0007 — Локальный stateful tier в docker-compose до Phase 3
status: Accepted
date: 2026-04-30
related:
  - docker-compose.yml
  - docs/PROJECT_PLAN.md
  - docs/adr/0001-databases-on-vm-not-k8s.md
  - docs/adr/0004-wireguard-mesh-zero-trust.md
---

# ADR-0007: Локальный stateful tier в docker-compose до Phase 3

## Status
Accepted (2026-04-30).

## Context
По плану Phase 2 микросервисы должны коннектиться к stateful-tier (`postgres`/`redis`/`mongo`) на узле `az-db` через WireGuard overlay (`10.100.0.11`).

Audit на 2026-04-30 показал блокеры:
1. **WG mesh не работает.** На `az-app` `wg show` показывает только `[Interface]`, ноль peer'ов. Шаблон роли `05-overlay-network` рендерится только если `wg_public_key` определён в hostvars каждого пира — это требует, чтобы роль одним прогоном `ansible-playbook` собрала факты со **всех** узлов и потом отрендерила шаблон. На az-app роль прошла, но факты с других узлов не собрались.
2. **PG/Redis/Mongo/etcd слушают только на `127.0.0.1`.** Даже если бы mesh работал, никто извне до них не достучится. Роль `06-stateful-tier` устанавливает пакеты, но не правит `bind_address`/`listen_addresses`.

Чинить обе проблемы — это самостоятельная Phase 2.5/3 (требует прогона ansible на всех узлах одновременно + дописывания роли). Блокировать развитие приложения до этого — нерационально.

## Decision
До Phase 3 stateful tier поднимается **локально на `az-app`** в том же `docker-compose.yml`, что и приложение:
- `postgres:16-alpine` под именем `postgres` в bridge-сети `aegis-net`.
- `redis:7-alpine` под именем `redis` там же.
- Сервисы (`ledger-api`, `matcher`) коннектятся через docker-DNS (`POSTGRES_HOST=postgres`, `REDIS_HOST=redis`).

Соответствует [PROJECT_PLAN.md §5 Phase 1–2](../PROJECT_PLAN.md#5-развитие-проекта-фазы): "сначала monolith on docker-compose, потом декомпозиция, потом переложение".

## Consequences

### Положительные
- **Reality.** Реально работающие end-to-end сценарии (PG insert + idempotency, Redis-based reconciliation) можно проверить уже сегодня.
- **Не блокируем разработку.** Phase 2.5/3 (mesh + bind) идёт параллельно.
- **Чистый путь миграции.** Переключение в Phase 3 — это **только изменение env-vars** (`POSTGRES_HOST=10.100.0.11`) и удаление двух services из compose. Код приложения не меняется.
- **Соответствует плану.** Это не "случайный компромисс", а явный шаг по PROJECT_PLAN.md.

### Отрицательные / Цена
- **Не используется az-db для своей цели.** Узел существует, диски смонтированы (см. [ADR-0002](0002-disk-isolation-per-database.md)), но данные приложения временно лежат в local volume на az-app.
- **Не тестируется WG mesh-путь.** Phase 3 переложение поднимет проблемы, которые сейчас скрыты (latency, MTU, потеря пакетов).
- **Two volumes на az-app.** `pgdata`, `redisdata` — `docker volume`, лежат на os-disk az-app. При `docker compose down --volumes` данные пропадут.

### Что станет проще / сложнее в будущем
- **Проще:** разработчик может работать с тем же compose локально на ноутбуке (1-в-1 как на az-app), нет зависимости от облака.
- **Сложнее:** Phase 3 сложнее, чем казалось — придётся одновременно (а) починить mesh, (б) перенастроить bind БД, (в) переключить env-vars. По уму — отдельный ADR на момент перехода.

## Alternatives considered

### Alt 1: ждать Phase 2.5 / 3 (починить mesh + bind БД, потом подключить из приложения)
Отвергли: приложение не движется, на ревью видны только заглушки. Реалистичный объём фикса — несколько часов работы с мульти-узловым ansible, может не сработать с первого раза.

### Alt 2: подключаться к az-db через VNet IP (10.10.1.5), без overlay
Отвергли: нарушает [ADR-0004](0004-wireguard-mesh-zero-trust.md) (Zero-Trust mesh — главная архитектурная фишка проекта). И всё равно блокируется bind на 127.0.0.1.

### Alt 3: захостить только PG локально, Redis на az-db через VNet
Отвергли: непоследовательно (один сервис ходит локально, другой через сеть), сложнее объяснять, не упрощает.

### Alt 4: использовать managed PG / Redis в Azure
Отвергли: смысл проекта — показать управление инфрой самостоятельно ([ADR-0001](0001-databases-on-vm-not-k8s.md)).

## Migration plan (Phase 3)

1. Прогнать `ansible-playbook` на всех узлах одновременно, проверить `wg show wg0` на каждом — все peer'ы handshake'нулись.
2. Дополнить роль `06-stateful-tier`:
   - `postgresql.conf`: `listen_addresses = '10.100.0.11'` (overlay IP узла)
   - `pg_hba.conf`: `host all all 10.100.0.0/24 md5`
   - `redis.conf`: `bind 10.100.0.11`
3. Сменить env-vars в `docker-compose.yml`:
   ```diff
   - POSTGRES_HOST=postgres
   + POSTGRES_HOST=10.100.0.11
   - REDIS_HOST=redis
   + REDIS_HOST=10.100.0.11
   ```
4. Удалить services `postgres:` и `redis:` из compose.
5. (Опционально) `docker volume rm aegis-app_pgdata aegis-app_redisdata` после миграции данных.
6. Закрыть этот ADR `Superseded by` новым (ADR-00XX «Stateful tier на az-db через overlay»).

## References
- [docker-compose.yml](../../docker-compose.yml) — текущий compose со встроенными PG/Redis.
- [docs/runbooks/deploy-services.md](../runbooks/deploy-services.md) — как раскатать.
- [PROJECT_PLAN §5](../PROJECT_PLAN.md#5-развитие-проекта-фазы).
