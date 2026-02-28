# 01-configmap-secret

## Задача
Прокинуть конфиг без пересборки image и разделить конфиг/секреты.

## Проверка
```bash
kubectl -n lab get cm
kubectl -n lab get secret
kubectl -n lab exec -it <pod> -- env | grep APP_
```
