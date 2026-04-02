# 16. Docker → Kubernetes: мост

## Зачем это важно

Docker Compose — не оркестратор. Он не умеет автоскейлинг, rolling update с readiness gates, multi-node деплой. Kubernetes решает эти задачи, но мыслит другими примитивами. Этот модуль строит мост: берём работающий Compose-стек и переводим его в K8s-манифесты.

```text
Compose                        Kubernetes
──────────────────────────────────────────────
services:                  →   Deployment + Service
  api:                     →   Pod spec внутри Deployment
    image: myapp:1.0.0     →   containers[].image
    ports: "8080:8080"     →   Service type: ClusterIP/NodePort
    environment:           →   ConfigMap / Secret
    volumes:               →   PersistentVolumeClaim
    healthcheck:           →   livenessProbe / readinessProbe
    deploy.replicas:       →   spec.replicas
    depends_on:            →   (нет аналога — K8s ожидает crash tolerance)
```

---

## Prereq

- Пройдены модули 01–12 (понимание Compose, build, networking, storage).
- `kubectl` установлен (опционально — для проверки манифестов).
- Опционально: `minikube` или `kind` для локального запуска.
- Опционально: `kompose` (`go install github.com/kubernetes/kompose@latest`).

---

## Часть 1 — Mapping: Compose → Kubernetes примитивы

### Полная таблица маппинга

| Compose | Kubernetes | Примечание |
|---|---|---|
| `services.api` | `Deployment` + `Service` | Один сервис = 2 ресурса |
| `image:` | `containers[].image` | Идентично |
| `ports: "8080:80"` | `Service` (ClusterIP/NodePort/LB) | NodePort = publish на хост |
| `environment:` | `ConfigMap` (не-secret) / `Secret` (secret) | Никогда `ENV` для паролей |
| `volumes:` (named) | `PersistentVolumeClaim` (PVC) | Декларативное хранилище |
| `volumes:` (bind mount) | `HostPath` (нежелательно) | Только для dev/debug |
| `healthcheck:` | `livenessProbe` + `readinessProbe` | В K8s два типа health |
| `deploy.replicas:` | `spec.replicas` | Или `HorizontalPodAutoscaler` |
| `deploy.resources:` | `resources.limits/requests` | Структурно идентично |
| `restart: always` | `restartPolicy: Always` (дефолт) | В K8s всегда restart |
| `depends_on:` | — (нет аналога) | Приложение должно быть tolerant |
| `networks:` | `NetworkPolicy` | Явная изоляция трафика |
| `secrets:` | `Secret` (base64) / External Secrets | Не Compose-style файл, а K8s-объект |
| `profiles:` | Kustomize overlays / Helm values | Разные окружения |
| `logging:` | Fluentd/Loki sidecar или node-level | K8s не настраивает log rotation per pod |
| `cap_drop: ALL` | `securityContext.capabilities.drop` | Идентичная концепция |
| `read_only: true` | `securityContext.readOnlyRootFilesystem` | Идентично |

### Чего в Compose нет

| K8s-концепция | Что делает | Аналог в Compose |
|---|---|---|
| `HorizontalPodAutoscaler` | Автоскейлинг по CPU/memory | Нет |
| `Ingress` / `Gateway API` | L7 маршрутизация с TLS | nginx reverse proxy вручную |
| `RBAC` | Контроль доступа к API | Нет |
| `Namespace` | Изоляция ресурсов | Нет (отдельные compose-проекты) |
| `readinessProbe` | Готов ли pod принимать трафик | healthcheck (только liveness) |
| `CronJob` | Расписание задач | Нет (cron на хосте) |
| `ServiceAccount` | Идентификация Pod | Нет |
| Rolling update strategy | Zero-downtime обновление | blue/green вручную (модуль 11) |

---

## Часть 2 — Kompose: автоматический перевод

`kompose` конвертирует compose.yaml в K8s-манифесты. Это стартовая точка, не финальная.

```bash
# Установить kompose
# Linux/Mac:
curl -L https://github.com/kubernetes/kompose/releases/latest/download/kompose-linux-amd64 -o kompose
chmod +x kompose && sudo mv kompose /usr/local/bin/

# Или через Go:
go install github.com/kubernetes/kompose@latest
```

### Практика: конвертация

```bash
# Конвертировать compose из capstone-проекта
kompose convert -f lab/source-compose.yaml -o lab/generated/

# Посмотреть что сгенерировалось
ls -la lab/generated/
# api-deployment.yaml
# api-service.yaml
# db-deployment.yaml
# db-service.yaml
# cache-deployment.yaml
# cache-service.yaml
# pg-data-persistentvolumeclaim.yaml
```

### Ограничения kompose

```bash
# Kompose НЕ генерирует:
# ❌ livenessProbe / readinessProbe (из healthcheck делает только livenessProbe)
# ❌ resource requests (только limits)
# ❌ NetworkPolicy
# ❌ Secrets из .env файла
# ❌ HPA (autoscaling)
# ❌ Ingress

# Kompose генерирует ЛИШНЕЕ:
# ⚠️ Лейблы kompose (io.kompose.service) — можно убрать
# ⚠️ HostPath volumes вместо PVC для bind mounts
```

---

## Часть 3 — Ручной перевод: правильные манифесты

### Исходный compose.yaml

```yaml
# lab/source-compose.yaml (из capstone web-db-cache)
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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 128M
          cpus: "0.50"

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
  pg_data:
```

### Эквивалентные K8s-манифесты

```bash
# Посмотреть hand-crafted манифесты
cat lab/manifests/api-deployment.yaml
cat lab/manifests/api-service.yaml
cat lab/manifests/db-deployment.yaml
cat lab/manifests/db-secret.yaml
cat lab/manifests/db-pvc.yaml
```

### Ключевые отличия от Compose

```yaml
# 1. healthcheck → livenessProbe + readinessProbe (ДВА типа)
# Compose:
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
  interval: 10s

# Kubernetes:
livenessProbe:           # "жив ли процесс?" → перезапустить при failure
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 10
readinessProbe:          # "готов ли принимать трафик?" → убрать из Service
  httpGet:
    path: /readyz
    port: 8080
  periodSeconds: 5


# 2. environment → ConfigMap + Secret
# Compose:
environment:
  DATABASE_URL: postgres://appuser:apppass@db:5432/appdb

# Kubernetes: разделить на ConfigMap (данные) и Secret (пароли)
# ConfigMap:
data:
  DATABASE_HOST: db
  DATABASE_NAME: appdb
  DATABASE_USER: appuser
# Secret:
data:
  DATABASE_PASSWORD: YXBwcGFzcw==    # base64


# 3. depends_on → init containers или retry-логика
# В K8s нет depends_on. Приложение ДОЛЖНО быть tolerant:
# - Retry подключения к БД
# - Или использовать init container:
initContainers:
  - name: wait-for-db
    image: busybox:1.36
    command: ['sh', '-c', 'until nc -z db 5432; do sleep 1; done']


# 4. deploy.resources → resources.requests + limits
# Compose:
deploy:
  resources:
    limits:
      memory: 128M

# Kubernetes: requests (гарантия) + limits (потолок)
resources:
  requests:
    memory: 64Mi
    cpu: 100m
  limits:
    memory: 128Mi
    cpu: 500m
```

---

## Часть 4 — Посмотреть манифесты

Все манифесты в `lab/manifests/`:

```bash
# API Deployment + Service
cat lab/manifests/api-deployment.yaml
cat lab/manifests/api-service.yaml

# DB: Deployment + Service + PVC + Secret
cat lab/manifests/db-deployment.yaml
cat lab/manifests/db-service.yaml
cat lab/manifests/db-pvc.yaml
cat lab/manifests/db-secret.yaml

# Cache: Deployment + Service
cat lab/manifests/cache-deployment.yaml
cat lab/manifests/cache-service.yaml
```

### Валидация манифестов (без кластера)

```bash
# Проверить YAML-синтаксис
yamllint lab/manifests/

# Dry-run через kubectl (нужен kubectl, НЕ нужен кластер)
kubectl apply --dry-run=client -f lab/manifests/
# deployment.apps/api created (dry run)
# service/api created (dry run)
# ...

# Kubeconform — строгая валидация по K8s JSON Schema
# docker run --rm -v "$PWD/lab/manifests:/manifests" \
#   ghcr.io/yannh/kubeconform /manifests/
```

### Запуск на локальном кластере (опционально)

```bash
# Если есть minikube или kind:
# minikube start
# kubectl apply -f lab/manifests/
# kubectl get pods -w
# kubectl port-forward svc/api 8080:8080
# curl http://localhost:8080/healthz
```

---

## Часть 5 — Security context: маппинг из модуля 07

```yaml
# Compose (модуль 07):
services:
  app:
    read_only: true
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    user: "1000:1000"

# Kubernetes эквивалент:
spec:
  containers:
    - name: app
      securityContext:
        readOnlyRootFilesystem: true
        allowPrivilegeEscalation: false    # = no-new-privileges
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        capabilities:
          drop: ["ALL"]
      # tmpfs → emptyDir с medium: Memory
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir:
        medium: Memory
        sizeLimit: 64Mi
```

---

## Часть 6 — Broken: типичные ошибки в K8s-манифестах

```bash
# Сценарий 1: неправильный selector
cat broken/bad-selector.yaml
# selector.matchLabels не совпадает с template.metadata.labels
# kubectl apply --dry-run=server покажет ошибку

# Сценарий 2: нет readinessProbe
cat broken/no-readiness.yaml
# Есть livenessProbe, но нет readinessProbe
# Pod получит трафик до полной готовности → 502 ошибки

# Сценарий 3: пароль в ConfigMap вместо Secret
cat broken/password-in-configmap.yaml
# POSTGRES_PASSWORD в ConfigMap — виден через kubectl describe
# Должен быть в Secret
```

---

## Часть 7 — Что дальше: за пределами этого модуля

| Тема | Где изучать |
|---|---|
| Helm charts | Шаблонизация манифестов |
| Kustomize | Overlays для dev/staging/prod |
| Argo CD / Flux | GitOps-деплой |
| Istio / Linkerd | Service mesh |
| Prometheus Operator | Мониторинг в K8s |
| cert-manager | Автоматические TLS-сертификаты |
| External Secrets Operator | Секреты из Vault/AWS SSM |

---

## Типовые ошибки

| Ошибка | Последствие | Исправление |
|---|---|---|
| `selector` не совпадает с `labels` | Deployment не управляет Pods | Проверить matchLabels == template labels |
| Нет `readinessProbe` | Трафик идёт на неготовый Pod | Добавить readinessProbe на `/readyz` |
| Пароль в `ConfigMap` | Виден в `kubectl get cm -o yaml` | Перенести в `Secret` |
| `depends_on` → нет retry | Приложение падает при старте | Добавить retry-логику или init container |
| `HostPath` вместо PVC | Привязка к ноде, нет disaster recovery | Использовать PersistentVolumeClaim |
| Нет `resources.requests` | Scheduler не может оптимально разместить Pod | Всегда указывать requests |
| `latest` в image tag | Недетерминированный деплой | Конкретный semver тег или digest |

---

## Вопросы для самопроверки

1. Чем `livenessProbe` отличается от `readinessProbe`? Зачем два типа?
2. Почему `depends_on` не имеет аналога в Kubernetes?
3. Что делает `requests` в `resources` и чем оно отличается от `limits`?
4. Почему пароли должны быть в `Secret`, а не в `ConfigMap`?
5. Как `NetworkPolicy` соотносится с `networks:` в Compose?
6. Что произойдёт, если `selector.matchLabels` не совпадает с `template.labels`?
7. Зачем нужен `init container` и как он решает проблему `depends_on`?
8. Как `emptyDir` с `medium: Memory` соотносится с `tmpfs` в Docker?
9. Какие концепции Compose нельзя выразить в Kubernetes без дополнительных инструментов?

---

## Файлы модуля

| Файл | Назначение |
|---|---|
| `lab/source-compose.yaml` | Исходный compose для конвертации |
| `lab/generated/` | Результат `kompose convert` |
| `lab/manifests/` | Hand-crafted K8s-манифесты |
| `broken/bad-selector.yaml` | Несовпадение selector и labels |
| `broken/no-readiness.yaml` | Нет readinessProbe |
| `broken/password-in-configmap.yaml` | Пароль в ConfigMap |

## Cleanup

```bash
./cleanup.sh
```
