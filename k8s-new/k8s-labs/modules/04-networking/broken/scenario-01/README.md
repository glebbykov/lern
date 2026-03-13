# Сценарий 01

## Симптом

Deployment работает, поды запущены. Но curl к Service возвращает
`Connection refused` или запрос зависает без ответа.

## Запуск

```bash
kubectl -n lab apply -f deploy.yaml
kubectl -n lab apply -f svc.yaml
kubectl -n lab get pods -l app=net-demo
```

## Задание

1. Выясните, почему Service не доставляет трафик до Pod.
2. Найдите несоответствие в конфигурации.
3. Исправьте и проверьте связность.

Начните:

```bash
kubectl -n lab get svc net-demo
kubectl -n lab get endpoints net-demo -o wide
kubectl -n lab get pods -l app=net-demo --show-labels
```

<details>
<summary><strong>Подсказка 1</strong></summary>

Service существует, Pod'ы запущены — но `Endpoints` пустой.
Kubernetes не знает, к каким Pod'ам отправлять трафик.

Как Service выбирает, каким Pod'ам маршрутизировать запросы?

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

Service использует `selector` для поиска Pod'ов.
Сравните `selector` в `svc.yaml` с `labels` Pod'ов:

```bash
kubectl -n lab get svc net-demo -o jsonpath='{.spec.selector}'
kubectl -n lab get pods -l app=net-demo --show-labels
```

Что вы видите?

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Значения в `selector` у Service и `labels` у Pod'ов должны
совпадать **точно**. Найдите различие — даже одна буква имеет значение.

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- Pod помечен `app: net-demo`, а `selector` у Service — `app: net-demo-wrong`.
- Service не находит ни одного Pod под этот selector.
- `Endpoints` пустой → `Connection refused`.

</details>

<details>
<summary><strong>Решение</strong></summary>

Исправить `selector` в `svc.yaml`: `net-demo-wrong` → `net-demo`.

```bash
kubectl -n lab apply -f ../../solutions/01-selector-mismatch/svc.yaml
kubectl -n lab get endpoints net-demo -o wide
```

</details>
