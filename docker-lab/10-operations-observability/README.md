# 10. Operations и observability

## Цель

Настроить минимально достаточную наблюдаемость: resource limits, метрики,
алерты, контроль роста логов и дашборд в Grafana.

---

## Теория

### Resource limits — защита от «шумного соседа»

Без лимитов один контейнер может исчерпать CPU или RAM всего хоста.

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: "0.50"        # не более 0.5 ядра
          memory: 256M        # OOMKiller при превышении
        reservations:
          cpus: "0.10"        # гарантированный минимум
          memory: 64M
```

> `deploy.resources` работает с `docker compose up` напрямую (Compose v2).
> В Swarm-режиме — то же самое. Не путайте с deprecated `mem_limit`.

Диагностика при OOMKill:
```bash
docker inspect <container> --format '{{.State.OOMKilled}}'
# true — контейнер убит по памяти, exit code 137
docker stats --no-stream   # текущее потребление всех контейнеров
```

### Лог-ротация — обязательна в production

```yaml
services:
  app:
    logging:
      driver: json-file
      options:
        max-size: "10m"      # максимум 10 МБ на файл
        max-file: "5"        # не более 5 файлов → 50 МБ итого
```

Без ротации `/var/lib/docker/containers/<id>/<id>-json.log` растёт
бесконечно и заполняет диск хоста.

Где лежат логи:
```bash
docker inspect <container> --format '{{.LogPath}}'
ls -lh $(docker inspect <container> --format '{{.LogPath}}')
```

### Метрики: что собирать минимально

| Метрика | Что означает | Алерт при |
|---|---|---|
| `container_cpu_usage_seconds_total` | Использование CPU | > 80% sustained |
| `container_memory_usage_bytes` | RSS память | > 90% от limit |
| `container_memory_failcnt` | Счётчик OOMKill | > 0 |
| `container_fs_writes_bytes_total` | Запись на диск | аномальный рост |
| HTTP 5xx rate | Ошибки приложения | > 1% запросов |
| `up` (probe) | Сервис отвечает | == 0 |

### Стек наблюдаемости

```text
App ──► cAdvisor ──► Prometheus ──► Grafana (дашборд)
                                 └──► Alertmanager (уведомления)
```

- **cAdvisor** — собирает метрики контейнеров (CPU, RAM, network, FS).
- **Prometheus** — scrape + хранение временных рядов + PromQL.
- **Grafana** — визуализация. Импорт дашборда ID `193` для cAdvisor.
- **Alertmanager** — маршрутизация алертов в Slack/email/PagerDuty.

### Alerting rules — основа

```yaml
# prometheus/alerts.yml
groups:
  - name: containers
    rules:
      - alert: ContainerOOMKilled
        expr: container_memory_failcnt > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.name }} OOMKilled"

      - alert: ContainerHighMemory
        expr: |
          container_memory_usage_bytes
            / container_spec_memory_limit_bytes > 0.9
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} memory > 90%"

      - alert: ContainerDown
        expr: absent(container_last_seen{name!=""})
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.name }} is down"
```

Подключение в `prometheus.yml`:
```yaml
rule_files:
  - /etc/prometheus/alerts.yml
```

---

## Практика

### 1. Поднимите стек наблюдаемости

```bash
docker compose -f lab/compose.yaml up -d
```

### 2. Проверьте endpoints

- App: <http://localhost:8085>
- cAdvisor: <http://localhost:8086>
- Prometheus: <http://localhost:9090>
- Grafana: <http://localhost:3000> (admin / admin)

### 3. Посмотрите метрики в Prometheus

Перейдите в <http://localhost:9090> → Status → Targets — все `UP`.

Выполните запросы:
```promql
# Использование памяти всех контейнеров (bytes)
container_memory_usage_bytes{image!=""}

# CPU в % (за последние 5 минут)
rate(container_cpu_usage_seconds_total{image!=""}[5m]) * 100

# Контейнеры с OOMKill
container_memory_failcnt > 0
```

### 4. Импортируйте дашборд в Grafana

1. Откройте Grafana: <http://localhost:3000>
2. Dashboards → Import → ID `193` → Load
3. Выберите Prometheus как datasource → Import

### 5. Проверьте resource limits

```bash
# Текущее потребление
docker stats --no-stream

# Лимиты конкретного контейнера
docker inspect <container> \
  --format 'mem limit: {{.HostConfig.Memory}}  cpu: {{.HostConfig.NanoCpus}}'
```

### 6. Проверьте лог-ротацию

```bash
# Где логи и какой размер?
docker inspect <container> --format '{{.LogPath}}'

# Конфигурация логгера
docker inspect <container> \
  --format '{{json .HostConfig.LogConfig}}' | python -m json.tool
```

### 7. Найдите проблему в broken/compose-nolimits.yaml

```bash
docker compose -f broken/compose-nolimits.yaml up -d
# Что не настроено? Что будет при spike трафика?
```

---

## Проверка

- Все контейнеры имеют `deploy.resources.limits`.
- Log rotation включена (`max-size`, `max-file`).
- Prometheus scrape'ит cAdvisor (`Status → Targets`).
- Grafana показывает метрики контейнеров.
- Понимаете, что будет при OOMKill (exit code 137).
- Можете написать простой alerting rule.

---

## Типовые ошибки

| Ошибка | Последствие | Исправление |
|---|---|---|
| Нет `max-size` в logging | Диск хоста заполняется логами | `logging.options.max-size: "10m"` |
| Нет memory limit | OOMKill всего хоста, не только контейнера | `deploy.resources.limits.memory` |
| Prometheus target down | Нет метрик → нет алертов | Проверить сеть между сервисами |
| Неверный target в prometheus.yml | Scrape ни одного контейнера | Имя сервиса == hostname в compose-сети |
| Нет `--start-period` в healthcheck | False OOMKill при медленном старте | Добавить `start-period: 30s` |

---

## Вопросы

1. Почему default `json-file` без ротации опасен?
2. Какие 3 метрики вы считаете базовыми для любого API?
3. Что такое exit code 137? Как отличить от 143?
4. Чем `limits` отличается от `reservations` в resource config?
5. Что нужно алертить в первую очередь? Составьте топ-3.

---

## Дополнительные задания

- Добавьте alerting rules для OOMKill и high memory в `prometheus/alerts.yml`.
- Настройте Alertmanager с webhook-уведомлением.
- Создайте нагрузку (`stress` или `ab`) и отследите в Grafana.
- Попробуйте превысить memory limit — посмотрите на `OOMKilled: true`.

---

## Файлы модуля

- `lab/compose.yaml` — app + cAdvisor + Prometheus + Grafana.
- `lab/prometheus/prometheus.yml` — конфиг scrape.
- `lab/prometheus/alerts.yml` — базовые alerting rules.
- `broken/compose-nolimits.yaml` — стенд без лимитов и ротации.
- `checks/verify.sh` — проверка доступности всех endpoints.

## Cleanup

```bash
./cleanup.sh
```
