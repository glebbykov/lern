# 02-get-describe-logs-exec

## Цель
Отработать базовый цикл диагностики Pod.

## Шаги
```bash
kubectl -n lab get pods -o wide
kubectl -n lab describe pod <pod>
kubectl -n lab logs <pod> --tail=200
kubectl -n lab exec -it <pod> -- sh
```

## Проверка
- Умеете назвать image, env, ports и состояние probes по `describe`.
