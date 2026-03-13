# Сценарий 01

## Симптом

Deployment применён, но Pod'ы не стартуют — они застыли
в `Pending` или `ContainerCreating` и не двигаются дальше.

## Запуск

```bash
kubectl -n lab apply -f pvc.yaml
kubectl -n lab apply -f deploy.yaml
kubectl -n lab get pods -l app=storage-demo -w
```

## Задание

1. Выясните, что мешает Pod'у запуститься.
2. Найдите незаполненный ресурс, от которого зависит запуск.
3. Исправьте и убедитесь, что Pod запустился.

Начните:

```bash
kubectl -n lab get pods -l app=storage-demo
kubectl -n lab describe pod -l app=storage-demo
kubectl -n lab get pvc -n lab
```

<details>
<summary><strong>Подсказка 1</strong></summary>

`describe pod` покажет в Events, почему Pod застрял.
Обычно это связано с ресурсом, который Pod ждёт перед запуском.

Что должно быть "готово" прежде чем контейнер стартует?

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

Посмотрите на состояние PVC:

```bash
kubectl -n lab get pvc
kubectl -n lab describe pvc demo-pvc
```

В каком статусе PVC? Что написано в Events?

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

PVC запрашивает конкретный `storageClassName`.
Проверьте, какие StorageClass'ы реально существуют в кластере:

```bash
kubectl get storageclass
```

Совпадает ли имя с тем, что указано в `pvc.yaml`?

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- `pvc.yaml` указывает `storageClassName: does-not-exist`.
- StorageClass с таким именем нет в кластере.
- PVC остаётся в `Pending` — том не создаётся.
- Pod не может смонтировать том → застревает в `Pending`.

</details>

<details>
<summary><strong>Решение</strong></summary>

Исправить `storageClassName` на существующий (например, `standard`
или узнать из `kubectl get storageclass`).

```bash
kubectl -n lab delete pvc demo-pvc --ignore-not-found
kubectl -n lab apply -f ../../solutions/01-pvc-pending/pvc.yaml
kubectl -n lab get pvc demo-pvc
```

</details>
