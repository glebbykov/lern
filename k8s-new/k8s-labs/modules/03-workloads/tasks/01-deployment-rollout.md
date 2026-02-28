# 01-deployment-rollout

## Шаги
1. Применить `deployment/v1`.
2. Обновить до `deployment/v2`.
3. Проверить историю rollout.
4. Выполнить rollback.

## Команды
```bash
kubectl -n lab apply -f manifests/deployment/v1
kubectl -n lab apply -f manifests/deployment/v2
kubectl -n lab rollout history deploy/workload-demo
kubectl -n lab rollout undo deploy/workload-demo
```
