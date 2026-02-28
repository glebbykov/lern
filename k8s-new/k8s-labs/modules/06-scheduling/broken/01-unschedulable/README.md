# 01-unschedulable

Сценарий: Pod не планируется из-за невозможного nodeSelector.

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Scheduler не находит ни одной ноды под constraints.
- Pod остается в `Pending` с `FailedScheduling`.

Диагностика:
```bash
kubectl -n lab get pod -l app=unschedulable-demo
kubectl -n lab describe pod -l app=unschedulable-demo
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab apply -f ../../solutions/01-unschedulable/deploy.yaml
kubectl -n lab rollout status deploy/unschedulable-demo --timeout=120s
```
</details>
