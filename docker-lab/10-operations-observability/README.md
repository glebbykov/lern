# 10. Operations и observability

## Зачем это важно

Без resource limits один контейнер убивает хост. Без ротации логов диск заполняется за ночь. Без метрик — невозможно отличить "тормозит" от "падает". Observability — это не опция, это условие работы в production.

```text
Проблема             → Симптом без observability  → Симптом с observability
────────────────────────────────────────────────────────────────────────────
Memory leak          → сервер недоступен            → алерт за 10 мин до краша
Диск заполнился      → все сервисы упали            → алерт при 80% заполнении
OOM Kill             → контейнер "просто упал"      → OOMKilled=true, exit 137
Медленный запрос     → "всё тормозит"               → p99 latency график
```

---

## Часть 1 — Resource limits

### Без лимитов: «шумный сосед»

```bash
# Запустить без лимитов (сломанный пример)
docker compose -f broken/compose-no-rotation.yaml up -d

# Сколько памяти доступно контейнеру? (0 = без лимита = весь хост)
docker inspect $(docker compose -f broken/compose-no-rotation.yaml ps -q) \
  --format '{{.HostConfig.Memory}}'
# 0  ← без ограничений

docker compose -f broken/compose-no-rotation.yaml down
```

### С лимитами

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: "0.50"    # не более 0.5 ядра
          memory: 256M    # OOMKill при превышении
        reservations:
          cpus: "0.10"    # гарантированный минимум
          memory: 64M
```

```bash
docker compose -f lab/compose.yaml up -d

# Реальное потребление vs лимит
docker stats --no-stream \
  --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'

# Лимиты конкретного контейнера (в байтах)
docker inspect observability-app \
  --format 'cpu_shares={{.HostConfig.CpuShares}} memory={{.HostConfig.Memory}}'
```

---

## Часть 2 — Лог-ротация

### Без ротации

```bash
# Путь к лог-файлу
docker inspect observability-app --format '{{.LogPath}}'

# Без ротации он будет расти бесконечно
# Смотрим текущий размер
ls -lh $(docker inspect observability-app --format '{{.LogPath}}')
```

### С ротацией

```yaml
services:
  app:
    logging:
      driver: json-file
      options:
        max-size: "10m"   # максимум 10 МБ на файл
        max-file: "3"     # не более 3 файлов → итого 30 МБ
```

```bash
# Проверить конфиг логгера
docker inspect observability-app \
  --format '{{.HostConfig.LogConfig.Type}} | max-size={{index .HostConfig.LogConfig.Config "max-size"}} max-file={{index .HostConfig.LogConfig.Config "max-file"}}'
# json-file | max-size=10m max-file=3
```

---

## Часть 3 — Стек метрик

```bash
docker compose -f lab/compose.yaml up -d
```

Доступные endpoint-ы:

| Сервис | URL | Что показывает |
|---|---|---|
| App | <http://localhost:8085> | Тестовое приложение |
| cAdvisor | <http://localhost:8086> | Метрики контейнеров |
| Prometheus | <http://localhost:9090> | TSDB + PromQL |
| Grafana | <http://localhost:3000> | Дашборды (admin/admin) |

```bash
# Все targets активны?
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep '"health"'
# "health": "up"  ← все должны быть up

# cAdvisor отдаёт метрики?
curl -s http://localhost:8086/metrics | grep container_memory_usage_bytes | head -3
```

---

## Часть 4 — PromQL: практические запросы

Перейди в <http://localhost:9090>:

```promql
# Память всех контейнеров в МБ
container_memory_usage_bytes{image!=""} / 1024 / 1024

# CPU usage в % (за последние 2 минуты)
rate(container_cpu_usage_seconds_total{image!=""}[2m]) * 100

# Топ-5 контейнеров по памяти
topk(5, container_memory_usage_bytes{image!=""})

# Процент использования памяти от лимита
container_memory_usage_bytes{image!=""}
  / container_spec_memory_limit_bytes{image!="", container_spec_memory_limit_bytes > 0}
  * 100

# Контейнеры без лимита памяти (опасно!)
container_spec_memory_limit_bytes == 0

# Контейнеры с OOMKill
container_memory_failcnt > 0

# Входящий сетевой трафик по контейнерам (bytes/sec)
rate(container_network_receive_bytes_total{image!=""}[1m])
```

---

## Часть 5 — Grafana: импорт дашборда

1. Открой <http://localhost:3000> (admin / admin)
2. **Dashboards → Import → ID `193` → Load**
3. Выбери Prometheus как datasource → **Import**

После импорта видишь:
- CPU usage по контейнерам
- Memory usage vs limit
- Network I/O
- Filesystem usage

---

## Часть 6 — Alerting rules

```yaml
# lab/prometheus/alerts.yml
groups:
  - name: containers
    rules:
      - alert: ContainerOOMKilled
        expr: container_memory_failcnt > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "OOMKill: {{ $labels.name }}"

      - alert: ContainerHighMemory
        expr: |
          container_memory_usage_bytes{image!=""}
            / container_spec_memory_limit_bytes{image!="", container_spec_memory_limit_bytes>0}
            > 0.9
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Memory > 90%: {{ $labels.name }}"

      - alert: ContainerDown
        expr: absent(container_last_seen{name!=""})
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container down: {{ $labels.name }}"
```

```bash
# Проверить что Prometheus видит правила
curl -s http://localhost:9090/api/v1/rules | python3 -m json.tool | grep '"name"'
```

---

## Часть 7 — Broken: нет ротации и лимитов

```bash
docker compose -f broken/compose-no-rotation.yaml up -d

# Что не настроено?
docker inspect $(docker compose -f broken/compose-no-rotation.yaml ps -q) \
  --format '{{.HostConfig.LogConfig.Type}} size={{index .HostConfig.LogConfig.Config "max-size"}}'
# json-file size=  ← max-size пустой

docker inspect $(docker compose -f broken/compose-no-rotation.yaml ps -q) \
  --format 'memory={{.HostConfig.Memory}}'
# memory=0  ← без лимита

docker compose -f broken/compose-no-rotation.yaml down
```

---

## Типовые ошибки

| Ошибка | Последствие | Исправление |
|---|---|---|
| Нет `max-size` в logging | Диск хоста заполняется логами | `max-size: "10m"` |
| Нет memory limit | OOM killer убивает другие процессы хоста | `deploy.resources.limits.memory` |
| Prometheus target down | Нет метрик, нет алертов | Проверить сеть между сервисами |
| Неверное имя сервиса в prometheus.yml | Scrape не работает | Имя target = имя сервиса в compose-сети |
| Нет `--start-period` в healthcheck | Ложные alerty при медленном старте | `start_period: 30s` |

---

## Вопросы для самопроверки

1. Почему `json-file` без `max-size` опасен в production?
2. Что такое exit code 137 и как через Prometheus узнать что произошёл OOM Kill?
3. Чем `limits` отличается от `reservations` в resource config?
4. Что такое `for: 2m` в alerting rule?
5. Какие 3 метрики обязательны для любого API-сервиса?
6. Как Prometheus находит cAdvisor? Где настраивается target?

---

## Cleanup

```bash
./cleanup.sh
```
