# Сценарий 01

## Симптом

Deployment создан, но rollout не завершается — Pod зависает
на этапе запуска, не переходит в `Running`.

## Запуск

```bash
kubectl -n lab apply -f deploy.yaml
kubectl -n lab get pods -l app=workload-demo -w
```

## Задание

1. Выясните, на каком этапе останавливается запуск Pod.
2. Найдите причину в конфигурации Deployment.
3. Исправьте и подтвердите завершение rollout.

Начните:

```bash
kubectl -n lab get pods -l app=workload-demo
kubectl -n lab describe pod -l app=workload-demo
```

<details>
<summary><strong>Подсказка 1</strong></summary>

Посмотрите на статус Pod — не `Running`, а что-то другое.
Kubernetes пытается запустить контейнер, но что-то мешает.

Обратите внимание на столбец `STATUS` в `kubectl get pods`.

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

В выводе `describe pod` найдите секцию `Events`.
Что kubernetes не может сделать перед запуском контейнера?

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Проблема на уровне образа. Проверьте поле `image` в манифесте.
Существует ли указанный тег в реестре?

```bash
docker pull $(kubectl -n lab get deploy workload-demo -o jsonpath='{.spec.template.spec.containers[0].image}')
```

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- Deployment использует образ с несуществующим тегом.
- Container runtime пытается скачать образ → получает `not found`.
- Pod переходит в `ErrImagePull` → `ImagePullBackOff`.
- Rollout бесконечно ждёт, пока Pod не станет `Ready`.

</details>

<details>
<summary><strong>Решение</strong></summary>

Исправить поле `image` на валидный тег.

```bash
kubectl -n lab apply -f ../../solutions/01-imagepull/deploy.yaml
kubectl -n lab rollout status deploy/workload-demo --timeout=120s
```

</details>
