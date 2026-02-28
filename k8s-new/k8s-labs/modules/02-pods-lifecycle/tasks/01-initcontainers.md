# 01-initcontainers

## Цель
Собрать Pod с initContainer, который ждет DNS и готовит данные.

## Шаги
1. Применить `manifests/initcontainer/pod.yaml`.
2. Проверить логи initContainer.
3. Проверить, что основной контейнер видит файл из `emptyDir`.

## Проверка
```bash
kubectl -n lab get pod init-wait-dns
kubectl -n lab logs init-wait-dns -c wait-dns
kubectl -n lab logs init-wait-dns -c app
```
