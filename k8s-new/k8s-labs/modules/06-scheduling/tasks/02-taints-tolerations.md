# 02-taints-tolerations

## Задача
Добавить taint на ноду и разрешить подам садиться через toleration.

## Команды
```bash
kubectl taint nodes <node-name> dedicated=lab:NoSchedule
kubectl -n lab apply -f manifests/taints/deploy.yaml
```
