---
title: Runbook — деплой и обновление микросервисов на az-app
status: stable
audience: [ops, llm]
last_verified: 2026-04-30
related:
  - ../../docker-compose.yml
  - ../../app/
  - deploy.md
  - ../PROJECT_PLAN.md
  - ../adr/0007-local-stateful-in-compose.md
---

# Runbook: микросервисы на az-app (Phase 2 — local stateful tier)

> Полный путь от пустого репо до работающих FastAPI-скелетов `ledger-api` / `normalizer` / `matcher` на `az-app`. Опирается на инфраструктуру, поднятую через [deploy.md](deploy.md) (Phase 0).

## Архитектура (Phase 2 — local stateful tier)

```
Operator (your laptop)
        │  rsync app/ + scp docker-compose.yml
        ▼
   ┌──────────────────────────────────────────────────┐
   │ az-app ($APP_IP)  · /opt/aegis-app/      │
   │                                                  │
   │  ┌─ aegis-net (docker bridge) ─────────────┐     │
   │  │                                         │     │
   │  │   postgres:16-alpine  ←─── ledger-api   │←─── 8081
   │  │   (volume: pgdata)         (port 80)    │     │
   │  │                                         │     │
   │  │   redis:7-alpine     ←──── matcher      │←─── 8083
   │  │   (volume: redisdata)      (port 80)    │     │
   │  │                                         │     │
   │  │                            normalizer   │←─── 8082
   │  │                            (no deps)    │     │
   │  └─────────────────────────────────────────┘     │
   └──────────────────────────────────────────────────┘
```

**Phase 2 компромисс:** PG и Redis запущены **локально на az-app** в том же compose. См. [ADR-0007](../adr/0007-local-stateful-in-compose.md). В Phase 3 `POSTGRES_HOST` / `REDIS_HOST` переключатся на overlay-IP реальной `az-db` (`10.100.0.11`).

Каждый сервис публикует:
- `GET /health` — liveness, всегда 200.
- `GET /ready` — **реальный** TCP/native ping deps. 200 если все ok, 503 иначе.
- `GET /metrics` — Prometheus (`aegis_requests_total`, `aegis_request_duration_seconds`, domain-specific).
- `POST /v1/<domain>` — реальная бизнес-логика (см. ниже).

Эндпоинты **снаружи закрыты** NSG (только `:22`, `:3000` и WG `:51820/udp`). Локальные curl-ы делаются по SSH.

---

## Предусловия

- [ ] Phase 0 завершена: инфра поднята через [deploy.md](deploy.md), все 5 узлов настроены, WireGuard mesh работает.
- [ ] Локально установлены: `rsync`, `ssh`, `scp` (для деплоя сорцов).
- [ ] Доступ по SSH к `az-app` работает: `ssh -F terraform/.generated/ssh_config az-app whoami` → `ansible_user`.
- [ ] `ansible_user` на az-app **в группе docker** (роль `04-runtime` это делает; если нет — `sudo usermod -aG docker ansible_user`).
- [ ] Public IP `az-app` известен (далее `$APP_IP`):
  ```bash
  APP_IP=$(awk '/^az-app/{for(i=1;i<=NF;i++) if($i ~ /^ansible_host=/) print substr($i,14)}' \
            /root/lern/aegis-capstone/ansible/inventory/hosts.ini)
  echo "az-app: $APP_IP"
  ```

---

## Шаг 1. Проверить, что Docker готов на az-app

```bash
ssh -F terraform/.generated/ssh_config az-app 'docker version && docker compose version'
```

Ожидаемый вывод:
```
Client: Docker Engine - Community
 Version:           27.x.x
 ...
Docker Compose version v2.x.x
```

Если `docker: command not found` или permission denied — прогнать роль `04-runtime`:
```bash
cd ansible/
ansible-playbook -i inventory/hosts.ini site.yml --tags runtime --limit az-app
```

---

## Шаг 2. Создать рабочую директорию

```bash
ssh -F terraform/.generated/ssh_config az-app '
  sudo mkdir -p /opt/aegis-app &&
  sudo chown -R ansible_user:ansible_user /opt/aegis-app
'
```

`/opt/aegis-app/` — каноническая локация compose-стека на узле.

---

## Шаг 3. Перенести сорцы и compose

С локальной машины (из корня репо `aegis-capstone/`):

```bash
SSH_KEY=~/.ssh/id_ed25519
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null"
HOST="ansible_user@$APP_IP"

# Сорцы сервисов
rsync -avz -e "ssh $SSH_OPTS" --delete app/ "$HOST":/opt/aegis-app/app/

# Compose-файл
scp $SSH_OPTS docker-compose.yml "$HOST":/opt/aegis-app/docker-compose.yml
```

`--delete` гарантирует, что удалённый `app/` будет точной копией локального (нет «забытых» файлов от предыдущего деплоя).

---

## Шаг 4. Сборка образов и запуск

```bash
ssh -F terraform/.generated/ssh_config az-app '
  cd /opt/aegis-app &&
  docker compose up -d --build
'
```

При первом запуске:
1. `docker compose build` — соберёт 3 образа (`aegis/ledger-api:0.1.0`, `aegis/normalizer:0.1.0`, `aegis/matcher:0.1.0`). 1–2 минуты.
2. `docker compose up -d` — запустит контейнеры в detached режиме, создаст сеть `aegis-net`.

При повторных запусках без изменений в `app/` — Docker использует layer cache, `build` занимает <5 сек.

---

## Шаг 5. Проверить статус и healthcheck

```bash
ssh -F terraform/.generated/ssh_config az-app 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
```

Ожидаемый вывод (через 10–15 сек после старта — `start_period` healthcheck'а):
```
NAMES        STATUS                    PORTS
ledger-api   Up 30 seconds (healthy)   0.0.0.0:8081->80/tcp
normalizer   Up 30 seconds (healthy)   0.0.0.0:8082->80/tcp
matcher      Up 30 seconds (healthy)   0.0.0.0:8083->80/tcp
```

Если хоть один `(unhealthy)`:
```bash
ssh -F terraform/.generated/ssh_config az-app 'docker inspect <name> --format "{{json .State.Health}}" | python3 -m json.tool'
```

Покажет последние 5 healthcheck-попыток с stdout/stderr и exit code.

---

## Шаг 6. Smoke-test эндпоинтов

С az-app:

```bash
ssh -F terraform/.generated/ssh_config az-app '
  for port in 8081 8082 8083; do
    echo "=== :$port ==="
    curl -s http://localhost:$port/health
    echo
    curl -s http://localhost:$port/ready
    echo
  done
'
```

Ожидаемый ответ от каждого:
```json
{"status":"ok","service":"ledger-api","version":"0.1.0"}
{"ready":true,"deps":{"postgres":"skipped","kafka":"skipped"}}
```

### Domain-эндпоинты (Phase 2 — реальная логика)

#### ledger-api: запись + idempotency

```bash
# Первый POST — статус "accepted", entry_id новый
curl -X POST http://localhost:8081/v1/entries \
  -H "Content-Type: application/json" \
  -d '{"tenant_id":"acme","debit_account":"a:1","credit_account":"a:2","amount_minor":12345,"currency":"USD","external_ref":"ref-001"}'
# → {"entry_id":"led_...","status":"accepted"}

# Повторный POST с тем же external_ref — статус "duplicate", entry_id ТОТ ЖЕ
curl -X POST http://localhost:8081/v1/entries -H "Content-Type: application/json" \
  -d '{"tenant_id":"acme","debit_account":"a:1","credit_account":"a:2","amount_minor":12345,"currency":"USD","external_ref":"ref-001"}'
# → {"entry_id":"led_<тот же>","status":"duplicate"}

# Что реально лежит в PG
docker exec postgres psql -U aegis -d aegis -c "SELECT * FROM journal_entries;"
```

#### matcher: register expected → match

```bash
# 1. Зарегистрировать ожидаемую транзакцию (TTL 1 час)
curl -X POST http://localhost:8083/v1/expected -H "Content-Type: application/json" \
  -d '{"tenant_id":"acme","external_ref":"ref-001","amount_minor":12345,"currency":"USD"}'
# → {"status":"registered","ttl_seconds":3600}

# 2. Прислать "actual" — совпало
curl -X POST http://localhost:8083/v1/match -H "Content-Type: application/json" \
  -d '{"tenant_id":"acme","external_ref":"ref-001","amount_minor":12345,"currency":"USD"}'
# → {"match_id":"mat_...","result":"matched","reason":"amount + currency + ref equal to expected"}

# 3. Повторно — expected уже снята (one-shot)
curl -X POST http://localhost:8083/v1/match -H "Content-Type: application/json" \
  -d '{"tenant_id":"acme","external_ref":"ref-001","amount_minor":12345,"currency":"USD"}'
# → {"match_id":"mat_...","result":"not_found","reason":"no expected record for ref"}

# 4. Discrepancy: ожидали 99999, прислали 11111
curl -X POST http://localhost:8083/v1/expected -H "Content-Type: application/json" \
  -d '{"tenant_id":"acme","external_ref":"ref-002","amount_minor":99999,"currency":"USD"}'
curl -X POST http://localhost:8083/v1/match -H "Content-Type: application/json" \
  -d '{"tenant_id":"acme","external_ref":"ref-002","amount_minor":11111,"currency":"USD"}'
# → {"match_id":"mat_...","result":"discrepancy","reason":"expected 99999 USD, got 11111 USD"}
```

#### normalizer (Phase 2.5 — пока stub, ждёт Kafka/Mongo)

```bash
curl -X POST http://localhost:8082/v1/normalize -H "Content-Type: application/json" \
  -d '{"tenant_id":"acme","source_format":"csv","raw_payload":"a\nb\nc"}'
# → {"feed_id":"feed_...","accepted_records":2,"status":"accepted"}
```

### Метрики

```bash
curl -s http://localhost:8081/metrics | grep -E '^aegis_'
```

Ожидаемые counter'ы и histogram'ы:
- `aegis_requests_total{service,method,path,status}` — счётчик HTTP-запросов
- `aegis_request_duration_seconds_*` — histogram latency
- domain-specific (per service): `aegis_ledger_entries_created_total`, `aegis_feeds_normalized_total`, `aegis_match_results_total`

---

## Шаг 7. Тестировать со своей машины (через SSH-туннель)

Не открываем порты 8081–8083 в NSG (Phase 1 — Zero-Trust). Туннель:

```bash
ssh -F terraform/.generated/ssh_config -L 8081:localhost:8081 -L 8082:localhost:8082 -L 8083:localhost:8083 az-app
```

В отдельном терминале:
```bash
curl http://localhost:8081/health  # ledger-api
curl http://localhost:8082/health  # normalizer
curl http://localhost:8083/health  # matcher
```

---

## Обновление сервисов (после правок в `app/`)

```bash
# с локальной машины
rsync -avz -e "ssh $SSH_OPTS" --delete app/ "$HOST":/opt/aegis-app/app/
ssh -F terraform/.generated/ssh_config az-app '
  cd /opt/aegis-app &&
  docker compose up -d --build
'
```

`--build` пересоберёт образ (Docker сам поймёт, что изменилось). `up -d` подменит работающий контейнер новым с нулевым downtime для других сервисов.

Только compose-файл (без правок в коде):
```bash
scp $SSH_OPTS docker-compose.yml "$HOST":/opt/aegis-app/docker-compose.yml
ssh -F terraform/.generated/ssh_config az-app 'cd /opt/aegis-app && docker compose up -d --force-recreate'
```

---

## Откат

```bash
ssh -F terraform/.generated/ssh_config az-app '
  cd /opt/aegis-app &&
  docker compose down
'
```

Удаляет контейнеры и сеть `aegis-net`. Образы остаются — последующий `up` поднимет тот же код. Чтобы зачистить и образы:
```bash
ssh ... 'cd /opt/aegis-app && docker compose down --rmi local --volumes'
```

---

## Известные проблемы и подводные камни

### 1. `(unhealthy)` сразу после `up -d`
Это нормально первые 10 секунд (`start_period: 10s`). Уверенно `(healthy)` появится после 1-го успешного healthcheck'а.

### 2. `localhost` внутри Alpine резолвится в IPv6 `::1`
Поэтому healthcheck использует **`127.0.0.1`** (IPv4), не `localhost`. Если меняешь — учитывай: `uvicorn --host 0.0.0.0` слушает только IPv4.

### 3. `docker: permission denied` при ssh-команде
Значит `ansible_user` не в группе `docker` или сессия старая (группа кэшируется). Решения:
- Переподключиться SSH (новая сессия → новые группы).
- Прогнать роль `04-runtime` (она делает `usermod -aG docker` + `meta: reset_connection`).
- Временный workaround: `sudo docker ...`.

### 4. Сборка падает на `pip install`
Чаще всего — нет интернета у узла или прокси. Проверь `curl https://pypi.org` с az-app. Образ `python:3.12-alpine` тянется с Docker Hub — тоже нужен наружу.

### 5. После `docker compose down` метрики обнулились
Counter'ы Prometheus в памяти процесса — рестарт = reset. Это ок для skeleton'а; в Phase 2 метрики будут уезжать в VictoriaMetrics через scrape, история сохранится там.

---

## Что дальше

### Phase 2.5 — `normalizer` подключить к Kafka + Mongo
В local compose добавить `kafka` (KRaft single broker) и `mongo`. `normalizer` начнёт публиковать `RawFeedReceived` в `raw-feeds` и сохранять payload в Mongo.

### Phase 3 — переложение stateful tier на az-db
1. **Починить WG mesh** на всех узлах (роль `05-overlay-network` должна прогнаться одним заходом на all → факты соберутся, шаблон отрендерится с peer'ами).
2. **Перенастроить bind** PG / Redis / Mongo / etcd на overlay-IP `10.100.0.11`/`.13` через роль `06-stateful-tier` (сейчас всё слушает `127.0.0.1`).
3. **Переключить env-vars** в `docker-compose.yml`:
   - `POSTGRES_HOST=10.100.0.11`
   - `REDIS_HOST=10.100.0.11`
   - убрать локальные `postgres:` / `redis:` services.
4. См. [ADR-0007](../adr/0007-local-stateful-in-compose.md).

### Phase 4 — оставшиеся сервисы
`ingest-api` (внешний REST), `reconcile-batch-worker` (cron + etcd lock), `report-api`, `alerter`, `archiver` — см. [PROJECT_PLAN §3](../PROJECT_PLAN.md#3-сервисы-и-маппинг-на-инфраструктуру).

### VictoriaMetrics scrape
Каждый сервис уже отдаёт `/metrics`. После Phase 3 прописать в `prometheus.yml` (или VM-config) static targets `host.docker.internal:8081/8082/8083` или подключить через docker network alias.
