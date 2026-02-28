# 01-selector-mismatch

Сценарий: Service selector не совпадает с labels Pod.

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Service выбирает несуществующие Pod.
- `Endpoints` пустой.
- Запросы к Service завершаются ошибкой.

Диагностика:
```bash
kubectl -n lab get svc net-demo -o yaml
kubectl -n lab get pods -l app=net-demo
kubectl -n lab get endpoints net-demo -o wide
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab apply -f ../../solutions/01-selector-mismatch/svc.yaml
kubectl -n lab get endpoints net-demo -o wide
```
</details>
