# 03-statefulset-with-pvc

## Задача
Запустить StatefulSet с `volumeClaimTemplates` и headless Service.

## Проверка
```bash
kubectl -n lab get sts
kubectl -n lab get pvc
kubectl -n lab get pods -l app=stateful-demo
```
