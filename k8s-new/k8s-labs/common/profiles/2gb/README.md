# 2GB profile

Минимальные настройки ресурсов для стенда с нодами ~2GB RAM.

Применение:
```bash
kubectl apply -f metrics-server-patch.yaml
kubectl apply -f ingress-nginx-controller-patch.yaml
```

Примечание: патчи применяются после установки соответствующих компонентов.
