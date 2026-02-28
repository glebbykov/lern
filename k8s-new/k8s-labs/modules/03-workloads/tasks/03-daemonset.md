# 03-daemonset

## Цель
Убедиться, что DaemonSet запускает Pod на каждом узле.

## Проверка
```bash
kubectl -n lab apply -f manifests/daemonset/ds.yaml
kubectl -n lab get ds
kubectl -n lab get pods -l app=node-agent -o wide
kubectl get nodes
```
