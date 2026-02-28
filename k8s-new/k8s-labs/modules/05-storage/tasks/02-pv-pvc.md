# 02-pv-pvc

## Задача
Создать PVC и убедиться в корректном bind.

## Проверка
```bash
kubectl -n lab apply -f manifests/pvc/pvc.yaml
kubectl -n lab get pvc
```
