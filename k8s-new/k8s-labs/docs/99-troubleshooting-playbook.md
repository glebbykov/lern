# 99-troubleshooting-playbook

## Runbook: 502/504
1. Проверить ingress controller и ingress resource.
2. Проверить Service и Endpoints/EndpointSlice.
3. Проверить readiness Pod.
4. Проверить логи приложения.
5. Проверить ресурсы/pressure на ноде.

## Команды
```bash
kubectl get ingress -A
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=200
kubectl -n lab get svc,endpoints,endpointslices
kubectl -n lab get pods -o wide
kubectl -n lab describe pod <pod>
kubectl -n lab logs <pod> --tail=200
kubectl top nodes
kubectl top pods -n lab
```

## Типовые признаки
- `Readiness probe failed` -> Service не маршрутизирует в Pod.
- `OOMKilled` -> пересмотреть requests/limits.
- `no endpoints available` -> mismatch selector или Pod not Ready.
- DNS ошибки -> проверить CoreDNS и `resolv.conf` внутри Pod.
