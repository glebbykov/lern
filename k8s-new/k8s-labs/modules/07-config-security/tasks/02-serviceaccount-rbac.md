# 02-serviceaccount-rbac

## Задача
Создать SA, Role и RoleBinding только на чтение Pod в namespace `lab`.

## Проверка
```bash
kubectl -n lab auth can-i get pods --as=system:serviceaccount:lab:pod-reader
kubectl -n lab auth can-i delete pods --as=system:serviceaccount:lab:pod-reader
```
