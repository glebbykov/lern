# 01-labels-selectors

## Задача
Промаркировать ноды и запланировать deployment через `nodeSelector`.

## Команды
```bash
kubectl label node <node-name> disktype=ssd --overwrite
kubectl -n lab apply -f manifests/selectors/deploy.yaml
```
