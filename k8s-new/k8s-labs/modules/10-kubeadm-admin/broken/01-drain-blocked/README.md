# 01-drain-blocked

Сценарий: `drain` блокируется из-за слишком строгого PDB.

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Deployment имеет 1 replica.
- PDB `minAvailable: 1` запрещает eviction единственного Pod.
- `kubectl drain` сообщает, что не может выселить Pod.

Диагностика:
```bash
kubectl -n lab get pdb
kubectl -n lab describe pdb drain-demo-pdb
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab apply -f ../../solutions/01-drain-blocked/pdb.yaml
kubectl -n lab get pdb drain-demo-pdb -o yaml
```
</details>
