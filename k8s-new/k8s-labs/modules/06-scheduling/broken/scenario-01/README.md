# Сценарий 01

## Симптом

Deployment применён. Pod'ы находятся в `Pending` неограниченно долго —
они не переходят в `Running` независимо от времени ожидания.

## Запуск

```bash
kubectl -n lab apply -f deploy.yaml
kubectl -n lab get pods -l app=unschedulable-demo -w
```

## Задание

1. Выясните, почему Scheduler не может разместить Pod.
2. Найдите ограничение, которому не соответствует ни одна нода.
3. Исправьте и подтвердите, что Pod запланирован.

Начните:

```bash
kubectl -n lab get pods -l app=unschedulable-demo
kubectl -n lab describe pod -l app=unschedulable-demo
```

<details>
<summary><strong>Подсказка 1</strong></summary>

Посмотрите на Events в `describe pod`. Scheduler объясняет,
почему не может разместить Pod — найдите строку с `FailedScheduling`.

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

Scheduler перебирает все ноды и проверяет каждое ограничение Pod'а.
Какие ограничения на размещение Pod'а прописаны в манифесте?

```bash
kubectl -n lab get deploy unschedulable-demo -o yaml | grep -A 10 "nodeSelector\|affinity\|tolerations"
```

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

В манифесте задан `nodeSelector`. Проверьте, есть ли в кластере
нода с таким label:

```bash
kubectl get nodes --show-labels
```

Совпадают ли значения?

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- `nodeSelector` содержит `dedicated: impossible-label`.
- Ни одна нода в кластере не имеет этого label.
- Scheduler не может найти подходящую ноду → `FailedScheduling`.
- Pod бесконечно остаётся в `Pending`.

</details>

<details>
<summary><strong>Решение</strong></summary>

Убрать или исправить `nodeSelector` на реально существующие labels нод.

```bash
kubectl -n lab apply -f ../../solutions/01-unschedulable/deploy.yaml
kubectl -n lab rollout status deploy/unschedulable-demo --timeout=120s
```

</details>
