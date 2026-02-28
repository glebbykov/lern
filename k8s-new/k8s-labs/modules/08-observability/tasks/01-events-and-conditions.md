# 01-events-and-conditions

## Задача
Научиться читать таймлайн деградации из events.

## Команды
```bash
kubectl get events -A --sort-by=.lastTimestamp
kubectl -n lab describe pod <pod>
```
