# 00-kubectl-cheatsheet

## Частые команды
```bash
kubectl get pods -A -o wide
kubectl get deploy,svc -n lab
kubectl describe pod <pod> -n lab
kubectl logs <pod> -n lab --tail=200
kubectl exec -it <pod> -n lab -- sh
kubectl apply -f <file>
kubectl delete -f <file>
```

## Форматы вывода
```bash
kubectl get pod <pod> -n lab -o yaml
kubectl get pod <pod> -n lab -o jsonpath='{.status.podIP}'
kubectl get endpoints <svc> -n lab -o wide
```

## Labels / annotate
```bash
kubectl label ns lab owner=student --overwrite
kubectl annotate deploy app runbook=docs/99-troubleshooting-playbook.md --overwrite
```
