# 02-nodeport

## Задача
Поднять NodePort и проверить доступ с ноды/локальной машины.

## Проверка
```bash
kubectl -n lab apply -f manifests/nodeport/svc-nodeport.yaml
kubectl -n lab get svc net-demo-nodeport
```
