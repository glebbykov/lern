# project-a-platform-namespace

Цель: собрать минимальный platform namespace с базовой безопасностью и лимитами.

## Минимальный состав
- namespace `platform`
- default deny NetworkPolicy
- ResourceQuota + LimitRange
- ingress для demo app (по желанию)

## Проверка
```bash
kubectl get ns platform
kubectl -n platform get resourcequota,limitrange
kubectl -n platform get networkpolicy
```
