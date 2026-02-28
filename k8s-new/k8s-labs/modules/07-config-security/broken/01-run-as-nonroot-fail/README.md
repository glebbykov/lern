# 01-run-as-nonroot-fail

Сценарий: включен `runAsNonRoot`, но образ стартует как root.

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Admission/kubelet отклоняет запуск контейнера с root user.
- Pod застревает в `CreateContainerConfigError` или `CrashLoop` (зависит от runtime).

Диагностика:
```bash
kubectl -n lab describe pod -l app=security-fail
kubectl -n lab get events --sort-by=.lastTimestamp | tail -n 20
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab apply -f ../../solutions/01-run-as-nonroot-fail/deploy.yaml
kubectl -n lab rollout status deploy/security-fail --timeout=120s
```
</details>
