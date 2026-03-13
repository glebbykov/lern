# Сценарий 01

## Симптом

Попытка освободить ноду зависает. `kubectl drain` не завершается —
команда висит и не выселяет Pod'ы с ноды.

## Запуск

```bash
kubectl -n lab apply -f deploy.yaml
kubectl -n lab apply -f pdb.yaml
# Затем попробуйте дренировать ноду:
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

## Задание

1. Выясните, что блокирует выселение Pod'а с ноды.
2. Найдите конфликт между текущим состоянием и политикой.
3. Исправьте ситуацию так, чтобы drain прошёл.

Начните:

```bash
kubectl -n lab get pods -l app=drain-demo
kubectl -n lab get pdb
kubectl -n lab describe pdb drain-demo-pdb
```

<details>
<summary><strong>Подсказка 1</strong></summary>

`kubectl drain` выселяет Pod'ы через механизм Eviction API.
Но есть объект, который может **запретить** выселение Pod'а,
если это нарушит минимальную доступность.

Какой объект управляет минимальным числом живых Pod'ов?

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

Посмотрите на PDB (PodDisruptionBudget):

```bash
kubectl -n lab describe pdb drain-demo-pdb
```

Сколько Pod'ов должно быть `Available` согласно политике?
Сколько реально запущено сейчас?

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Если `minAvailable: 1`, а у Deployment только 1 реплика —
выселение единственного Pod'а нарушит политику.

Kubernetes не может одновременно выселить Pod И сохранить
требуемое число доступных Pod'ов. Что нужно изменить?

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- Deployment имеет `replicas: 1`.
- PDB установлен `minAvailable: 1`.
- Eviction API отклоняет выселение: оно нарушит PDB.
- `kubectl drain` бесконечно ждёт, пока Pod можно будет выселить.

</details>

<details>
<summary><strong>Решение</strong></summary>

Два варианта:
- Уменьшить `minAvailable` до `0`.
- Увеличить `replicas` до `2` (тогда выселение одного не нарушает PDB).

```bash
kubectl -n lab apply -f ../../solutions/01-drain-blocked/pdb.yaml
kubectl -n lab get pdb drain-demo-pdb -o yaml
```

</details>
