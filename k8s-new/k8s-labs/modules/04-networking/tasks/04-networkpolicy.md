# 04-networkpolicy

## Задача
Сделать default deny и затем точечно разрешить DNS и доступ к приложению.

## Проверка
```bash
kubectl -n lab apply -f manifests/netpol/default-deny.yaml
kubectl -n lab apply -f manifests/netpol/allow-dns.yaml
kubectl -n lab apply -f manifests/netpol/allow-app.yaml
```
