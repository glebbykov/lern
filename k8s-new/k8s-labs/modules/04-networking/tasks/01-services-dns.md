# 01-services-dns

## Задача
Развернуть приложение и проверить DNS-resolve сервиса из debug pod.

## Команды
```bash
kubectl -n lab apply -f manifests/services
kubectl -n lab run dnscheck --image=busybox:1.36 --restart=Never -- nslookup net-demo.lab.svc.cluster.local
```
