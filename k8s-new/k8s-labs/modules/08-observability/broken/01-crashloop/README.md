# 01-crashloop

Сценарий: контейнер аварийно завершается, Pod уходит в CrashLoopBackOff.

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Команда контейнера завершает процесс с кодом `1`.
- Kubernetes перезапускает контейнер с backoff.
- Важно сравнивать текущие и предыдущие логи контейнера.

Диагностика:
```bash
kubectl -n lab get pod -l app=obs-broken
kubectl -n lab logs -l app=obs-broken
kubectl -n lab logs -l app=obs-broken --previous
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab apply -f ../../solutions/01-crashloop/deploy.yaml
kubectl -n lab rollout status deploy/obs-broken --timeout=120s
```
</details>
