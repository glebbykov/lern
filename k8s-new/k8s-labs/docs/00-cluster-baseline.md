# 00-cluster-baseline

## Инвентаризация
```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl get ns
```

## Базовые sanity checks
```bash
kubectl -n kube-system get deploy coredns
kubectl -n kube-system get ds -l k8s-app=kube-proxy
kubectl get --raw='/readyz?verbose'
```

## Что сохранить в notes
- Версия Kubernetes.
- CNI plugin и версия.
- Режим kube-proxy (`iptables` или `ipvs`).
- Наличие `metrics-server`.
