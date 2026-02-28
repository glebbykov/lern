# kubeadm-2nodes

Минимальный профиль стенда:
- 1 control-plane
- 1 worker
- CNI установлен

## Что проверить
```bash
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide
```
