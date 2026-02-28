# 01-imagepull

Сценарий: Deployment с несуществующим image tag.

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Runtime не может скачать образ.
- Pod переходит в `ImagePullBackOff`/`ErrImagePull`.
- Приложение не стартует, rollout зависает.

Диагностика:
```bash
kubectl -n lab get pods -l app=workload-demo
kubectl -n lab describe pod -l app=workload-demo
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab apply -f ../../solutions/01-imagepull/deploy.yaml
kubectl -n lab rollout status deploy/workload-demo --timeout=120s
```
</details>
