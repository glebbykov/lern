# Сценарий 01

## Симптом

Контейнер запущен и отвечает на запросы изнутри, но Pod застрял
в `0/1 Running` — Service его не видит, трафик не маршрутизируется.

## Запуск

```bash
kubectl -n lab apply -f deploy.yaml
kubectl -n lab get pods -l app=probe-demo -w
```

## Задание

1. Выясните, почему Pod работает, но не считается готовым к трафику.
2. Найдите расхождение между конфигом пробы и реальным поведением приложения.
3. Исправьте и убедитесь, что Pod перешёл в `1/1 Ready`.

Начните:

```bash
kubectl -n lab describe pod -l app=probe-demo
kubectl -n lab get endpoints probe-demo -o wide
kubectl -n lab get events --sort-by=.lastTimestamp | tail -20
```

<details>
<summary><strong>Подсказка 1</strong></summary>

`Running` и `Ready` — разные вещи.
`Running` значит: процесс запущен.
`Ready` значит: проба подтвердила, что приложение готово принимать трафик.

Что именно проверяет readiness probe прямо сейчас?

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

Посмотрите вывод `describe pod` в секции Readiness.
Какой HTTP-ответ она получает? Попробуйте вручную:

```bash
kubectl -n lab exec -it <pod-name> -- wget -qO- localhost/
kubectl -n lab exec -it <pod-name> -- wget -qO- localhost/does-not-exist
```

Сравните ответы. Что происходит?

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Путь, по которому ходит проба, и путь, который реально отдаёт
приложение, — разные. Найдите в `deploy.yaml` параметр
`readinessProbe.httpGet.path`.

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- `readinessProbe.httpGet.path: /does-not-exist` — endpoint не существует.
- Приложение отвечает только на `/` → проба получает 404 → постоянный фейл.
- Pod остаётся `NotReady` → исключён из `Endpoints` → трафик не идёт.

</details>

<details>
<summary><strong>Решение</strong></summary>

Исправить `readinessProbe.httpGet.path` на `/`.

```bash
kubectl -n lab apply -f ../../solutions/02-readiness-fail/deploy.yaml
kubectl -n lab rollout status deploy/probe-demo --timeout=120s
kubectl -n lab get endpoints probe-demo -o wide
```

</details>
