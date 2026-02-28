# 03-workloads

Цель: выбирать правильный workload под задачу.

## Теория (расширенная)
- `Deployment` предназначен для stateless workloads и поддерживает rollout/rollback.
- Стратегия rolling update (`maxSurge`, `maxUnavailable`) влияет на скорость и доступность релиза.
- `StatefulSet` дает стабильную идентичность Pod и отдельные volume per replica.
- `DaemonSet` гарантирует запуск Pod на каждой подходящей ноде.
- `Job` выполняет задачу до завершения, `CronJob` запускает Job по расписанию.
- `PodDisruptionBudget` ограничивает добровольные disruption во время обслуживания кластера.

## Теоретические вопросы
1. Почему `Deployment` подходит для stateless-сервисов, а `StatefulSet` — для stateful?
2. Как `maxSurge` и `maxUnavailable` влияют на риски при релизе?
3. Когда использовать `Job`, а когда `CronJob`?
4. В чем ценность `DaemonSet` по сравнению с обычным `Deployment`?
5. Почему rollback в Deployment возможен без ручного пересоздания ресурса?
6. Как `PodDisruptionBudget` связан с операциями `drain`?

## Команды для прохождения
Команды ниже запускайте из директории текущего модуля.

```bash
# 1) Deployment v1
kubectl -n lab apply -f manifests/deployment/v1/
kubectl -n lab rollout status deploy/workload-demo --timeout=120s

# 2) Обновление на v2 и rollback
kubectl -n lab apply -f manifests/deployment/v2/deploy.yaml
kubectl -n lab rollout history deploy/workload-demo
kubectl -n lab rollout undo deploy/workload-demo

# 3) Job и CronJob
kubectl -n lab apply -f manifests/job/job.yaml
kubectl -n lab apply -f manifests/cronjob/cronjob.yaml
kubectl -n lab get job,cronjob
kubectl -n lab get events --sort-by=.lastTimestamp | tail -n 20

# 4) DaemonSet
kubectl -n lab apply -f manifests/daemonset/ds.yaml
kubectl -n lab get ds node-agent
kubectl -n lab get pods -l app=node-agent -o wide
```

## Порядок выполнения
1. Развернуть `Deployment v1` и проверить доступность.
2. Обновить на `v2`, проверить rollout history.
3. Сделать rollback и убедиться, что версия откатилась.
4. Запустить `Job` и `CronJob`, проверить события и логи.
5. Развернуть `DaemonSet` и убедиться в наличии Pod на каждой ноде.

## Что отработать
- Deployment: rollout/rollback.
- Job/CronJob: completions, backoff, расписание.
- DaemonSet: по Pod на узел.
- StatefulSet: стабильная идентичность + тома.

## Критерий готовности
Аргументированно выбираете Deployment vs StatefulSet vs Job.


