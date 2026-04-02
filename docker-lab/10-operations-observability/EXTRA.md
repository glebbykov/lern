# 10 — Дополнительные материалы

## Grafana Loki: centralized log aggregation (lab/loki/)

Стек: Loki (хранение) + Promtail (сбор) + Grafana (визуализация).

```bash
docker compose -f lab/loki/compose.yaml up -d

# Подождать 10 секунд, затем:
# Grafana:   http://localhost:3001  (admin/admin)
# Loki API:  http://localhost:3100/ready

# В Grafana:
#   1. Configuration → Data Sources → Add → Loki
#   2. URL: http://loki:3100
#   3. Explore → LogQL:
#      {container_name="loki-demo-app"} |= "GET"

docker compose -f lab/loki/compose.yaml down -v
```

**docker logs vs Loki:**

| Критерий | `docker logs` | Loki |
|---|---|---|
| Хранение | Локально на хосте | Централизованно |
| Поиск | grep | LogQL (label + text) |
| Retention | max-file/max-size | Настраиваемый |
| Multi-host | Нет | Да |
| Dashboard | Нет | Grafana |

---

## Custom Metrics: /metrics endpoint (lab/custom-metrics/)

Flask-приложение, экспортирующее бизнес-метрики для Prometheus:

```bash
docker compose -f lab/custom-metrics/compose.yaml up -d --build

# Метрики приложения
curl http://localhost:8096/metrics
# http_requests_total{method="GET",endpoint="/",status="200"} 42.0
# http_request_duration_seconds_bucket{endpoint="/",le="0.1"} 38
# app_active_connections 0.0

# Prometheus: http://localhost:9092
#   Query: rate(http_requests_total[5m])

# Grafana: http://localhost:3002 (admin/admin)

# Генерировать нагрузку:
for i in $(seq 1 50); do curl -s http://localhost:8096/ > /dev/null; done

docker compose -f lab/custom-metrics/compose.yaml down -v
```

**Типы метрик Prometheus:**

| Тип | Пример | Что показывает |
|---|---|---|
| Counter | `http_requests_total` | Только растёт (total count) |
| Histogram | `http_request_duration_seconds` | Распределение значений (buckets) |
| Gauge | `app_active_connections` | Растёт и падает (текущее значение) |
| Summary | `gc_duration_seconds` | Квантили (p50, p90, p99) |
