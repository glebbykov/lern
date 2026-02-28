# 01-pvc-pending

Сценарий: PVC запрашивает несуществующий StorageClass.

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- `storageClassName` указывает на класс, которого нет в кластере.
- PVC остается в `Pending`.
- Stateful workload не может смонтировать том и не стартует.

Диагностика:
```bash
kubectl -n lab get pvc demo-pvc
kubectl -n lab describe pvc demo-pvc
kubectl get storageclass
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab delete pvc demo-pvc --ignore-not-found
kubectl -n lab apply -f ../../solutions/01-pvc-pending/pvc.yaml
kubectl -n lab get pvc demo-pvc
```
</details>
