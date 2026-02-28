# 02-readiness-fail

Сценарий поломки: `readinessProbe` проверяет неверный HTTP path.

## Запуск сценария
```bash
kubectl -n lab apply -f deploy.yaml
kubectl -n lab get pods -l app=probe-demo -w
```

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Контейнер доступен по `/`, но проба проверяет `/does-not-exist`.
- Проба постоянно возвращает ошибку, Pod не становится `Ready`.
- Сервис исключает Pod из роутинга, так как endpoints для него не готовы.
- Это классический пример «приложение запущено, но недоступно через Service».

Быстрая диагностика:
```bash
kubectl -n lab describe pod -l app=probe-demo
kubectl -n lab get endpoints probe-demo -o wide
kubectl -n lab get events --sort-by=.lastTimestamp | tail -n 20
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

1. Исправить `readinessProbe.httpGet.path` на валидный путь (`/`).
2. Применить манифест из `solutions`.
3. Дождаться `Ready` и проверить endpoints.

Команды:
```bash
kubectl -n lab apply -f ../../solutions/02-readiness-fail/deploy.yaml
kubectl -n lab rollout status deploy/probe-demo --timeout=120s
kubectl -n lab get endpoints probe-demo -o wide
```
</details>
