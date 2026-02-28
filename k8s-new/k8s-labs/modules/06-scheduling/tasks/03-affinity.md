# 03-affinity

## Задача
Добавить node affinity и проверить решение scheduler.

## Проверка
```bash
kubectl -n lab describe pod <pod>
```
Смотрите секцию `Node-Selectors` и `Events`.
