# 01-drain-cordon

## Команды
```bash
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>
```

## Проверка
Workloads пересоздались на доступных нодах.
