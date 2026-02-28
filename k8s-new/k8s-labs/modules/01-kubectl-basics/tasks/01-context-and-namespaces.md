# 01-context-and-namespaces

## Цель
Научиться переключать контексты и работать с namespace.

## Шаги
```bash
kubectl config get-contexts
kubectl config current-context
kubectl get ns
kubectl create ns lab --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns lab owner=student --overwrite
```

## Проверка
- `kubectl get ns lab --show-labels` содержит label `owner=student`.
