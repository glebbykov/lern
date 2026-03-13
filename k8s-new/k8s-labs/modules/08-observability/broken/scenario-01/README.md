# Сценарий 01

## Симптом

Приложение развёрнуто, но Pod непрерывно перезапускается.
`RESTARTS` в `kubectl get pods` растёт с каждой секундой.

## Запуск

```bash
kubectl -n lab apply -f deploy.yaml
kubectl -n lab get pods -l app=obs-broken -w
```

## Задание

1. Выясните, почему Pod постоянно перезапускается.
2. Найдите, что происходит внутри контейнера при каждом запуске.
3. Исправьте и убедитесь, что Pod стабилен.

Начните:

```bash
kubectl -n lab get pod -l app=obs-broken
kubectl -n lab describe pod -l app=obs-broken
```

<details>
<summary><strong>Подсказка 1</strong></summary>

Когда Pod перезапускается, это значит, что PID 1 внутри завершился
с ненулевым exit code. Kubernetes видит это и перезапускает контейнер.

Что выводит контейнер перед завершением?

```bash
kubectl -n lab logs -l app=obs-broken
```

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

После перезапуска текущие логи — уже из нового запуска.
Чтобы увидеть логи предыдущего (упавшего) контейнера:

```bash
kubectl -n lab logs -l app=obs-broken --previous
```

Что он вывел перед смертью? Какой был exit code?

```bash
kubectl -n lab get pod -l app=obs-broken -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated}'
```

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Посмотрите, какую именно команду выполняет контейнер:

```bash
kubectl -n lab get deploy obs-broken -o jsonpath='{.spec.template.spec.containers[0].command}'
```

Эта команда должна работать постоянно — но что она делает на самом деле?

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- Команда контейнера: `["sh", "-c", "echo fail && exit 1"]`.
- Процесс завершается с кодом `1` немедленно после запуска.
- Kubernetes видит ненулевой exit code → перезапускает контейнер.
- Интервал перезапуска увеличивается по экспоненте (`CrashLoopBackOff`).

</details>

<details>
<summary><strong>Решение</strong></summary>

Заменить команду на нормально работающий процесс (например, nginx).

```bash
kubectl -n lab apply -f ../../solutions/01-crashloop/deploy.yaml
kubectl -n lab rollout status deploy/obs-broken --timeout=120s
```

</details>
