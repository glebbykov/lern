# 11 — Дополнительные материалы

## Canary Deployment (lab/canary/)

Nginx weight-based routing: 90% → stable, 10% → canary.

```bash
docker compose -f lab/canary/compose.yaml up -d

# Проверить распределение трафика
for i in $(seq 1 20); do curl -s http://localhost:8091; done
# ~18 ответов "stable-v1", ~2 ответа "canary-v2"

# Посмотреть заголовок X-Upstream
curl -v http://localhost:8091 2>&1 | grep X-Upstream

docker compose -f lab/canary/compose.yaml down
```

**Canary vs Blue/Green:**

| Критерий | Canary | Blue/Green |
|---|---|---|
| Трафик | Постепенный (1% → 5% → 25% → 100%) | Переключение 100% |
| Rollback | Убрать canary из upstream | Переключить обратно |
| Риск | Минимальный (мало пользователей) | Полный (все пользователи) |
| Сложность | Выше (weight routing) | Ниже (DNS/proxy switch) |

---

## Graceful Shutdown (lab/graceful-shutdown/)

Приложение корректно обрабатывает SIGTERM:

```bash
docker compose -f lab/graceful-shutdown/compose.yaml up -d --build

# Начать длинный запрос
curl http://localhost:8092/slow &

# Остановить контейнер (пока запрос идёт)
docker compose -f lab/graceful-shutdown/compose.yaml stop app

# Посмотреть логи
docker compose -f lab/graceful-shutdown/compose.yaml logs app
# → "Received SIGTERM, finishing in-flight requests..."
# → "Slow request completed"
# → "Graceful shutdown complete"

docker compose -f lab/graceful-shutdown/compose.yaml down
```

---

## Pre-Deploy DB Migration (lab/db-migration/)

Паттерн: migrator-контейнер применяет SQL-миграции ДО запуска приложения.

```bash
docker compose -f lab/db-migration/compose.yaml up -d

# Проверить что миграции прошли
docker compose -f lab/db-migration/compose.yaml logs migrator
# Applying: /migrations/001_create_notes.sql
# Applying: /migrations/002_add_category.sql
# Applying: /migrations/003_seed_data.sql
# All migrations applied successfully

# App стартует только после успешной миграции
curl http://localhost:8093
# app v2 (migrated)

# Проверить данные в БД
docker compose -f lab/db-migration/compose.yaml exec db \
  psql -U appuser -d appdb -c "SELECT * FROM notes;"

docker compose -f lab/db-migration/compose.yaml down -v
```

**Ключевой механизм:**
```yaml
migrator:
  restart: "no"    # запустился, применил миграции, завершился
app:
  depends_on:
    migrator:
      condition: service_completed_successfully  # ← app ждёт migrator
```
