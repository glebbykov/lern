# Сценарий 01

## Симптом

Deployment поднят, Pod в статусе `Running`. Но Service не отдаёт трафик —
curl возвращает ошибку, хотя контейнер запущен и работает.

## Запуск

```bash
kubectl -n lab apply -f deploy.yaml
kubectl -n lab get pods -l app=kb-web -w
```

## Задание

1. Выясните, почему Service не получает backend-адреса.
2. Найдите некорректно настроенный параметр.
3. Исправьте манифест и подтвердите, что трафик пошёл.

Начните расследование:

```bash
kubectl -n lab get pods -l app=kb-web
kubectl -n lab get endpoints kb-web
kubectl -n lab describe pod -l app=kb-web
```

<details>
<summary><strong>Подсказка 1</strong></summary>

Посмотрите на столбец `READY` — не только на статус `Running`.
Что означает `0/1`? Почему Pod работает, но считается не готовым?

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

Kubernetes убирает `NotReady` Pod из `Endpoints` сервиса.
Что именно решает — готов Pod к трафику или нет?

```bash
kubectl -n lab describe pod -l app=kb-web | grep -A 10 "Readiness"
```

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Readiness probe проверяет конкретный порт. Сравните:
- на каком порту реально слушает контейнер
- на какой порт настроена проба

Они совпадают? Проверьте `containerPort` в манифесте.

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- Контейнер слушает порт `80`, а `readinessProbe.httpGet.port` указывает `8080`.
- Проба постоянно фейлится → Pod остаётся `NotReady`.
- `NotReady` Pod не попадает в `Endpoints` → Service не маршрутизирует трафик.

</details>

<details>
<summary><strong>Решение</strong></summary>

Исправить `readinessProbe.httpGet.port`: `8080` → `80`.

```bash
kubectl -n lab apply -f ../../solutions/01-wrong-port/deploy.yaml
kubectl -n lab rollout status deploy/kb-web --timeout=120s
kubectl -n lab get endpoints kb-web -o wide
```

</details>
