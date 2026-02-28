# 01-wrong-port

Сценарий поломки: `readinessProbe` проверяет неправильный порт.

## Запуск сценария
```bash
kubectl -n lab apply -f deploy.yaml
kubectl -n lab get pods -l app=kb-web -w
```

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Контейнер реально слушает `80`, а проба идет в `8080`.
- Pod остается в статусе `NotReady`.
- Пока Pod не `Ready`, он не попадает в `Endpoints` сервиса.
- Сервис не получает живые backend-адреса, трафик не проходит.

Быстрая диагностика:
```bash
kubectl -n lab describe pod -l app=kb-web
kubectl -n lab get endpoints kb-web -o wide
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

1. Исправить `readinessProbe.httpGet.port` на `80`.
2. Применить исправленный манифест.
3. Проверить, что Pod стал `Ready`, а endpoints появились.

Команды:
```bash
kubectl -n lab apply -f ../../solutions/01-wrong-port/deploy.yaml
kubectl -n lab rollout status deploy/kb-web --timeout=120s
kubectl -n lab get endpoints kb-web -o wide
```
</details>
