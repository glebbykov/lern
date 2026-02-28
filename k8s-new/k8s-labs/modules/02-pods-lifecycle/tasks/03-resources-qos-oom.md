# 03-resources-qos-oom

## Цель
Понять влияние requests/limits и QoS на поведение контейнера.

## Упражнение
- Создайте Pod с низким memory limit и нагрузкой на память.
- Дождитесь `OOMKilled`.
- Сравните поведение при изменении requests/limits.

## Проверка
```bash
kubectl -n lab describe pod <pod>
kubectl -n lab get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
```
