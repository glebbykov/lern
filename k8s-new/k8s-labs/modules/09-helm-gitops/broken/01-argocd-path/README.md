# 01-argocd-path

Сценарий: Argo CD Application указывает неверный `spec.source.path`.

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Argo CD не находит chart/manifests по указанному пути.
- Синхронизация падает с ошибкой рендера или path-not-found.

Диагностика:
```bash
kubectl -n argocd get application demo-app -o yaml
kubectl -n argocd describe application demo-app
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl apply -f ../../solutions/01-argocd-path/app.yaml
```
</details>
