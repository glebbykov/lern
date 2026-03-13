# Broken Cluster Lab

Четыре сервиса развёрнуты в кластере. Каждый ведёт себя аномально.
Ваша задача — выявить причину и устранить неисправность.

---

## Сценарий 1: auth-service

```bash
kubectl -n lab apply -f auth-service.yaml
kubectl -n lab get pods -l app=auth-service -w
```

**Симптом:** Pod постоянно пересоздаётся. Счётчик `RESTARTS` растёт.
Никакой полезной нагрузки не выполняется.

Начните расследование:

```bash
kubectl -n lab get pods -l app=auth-service
kubectl -n lab describe pod -l app=auth-service
kubectl -n lab logs -l app=auth-service
```

<details>
<summary><strong>Подсказка 1</strong></summary>

Посмотрите на статус Pod — он не `Running`, он циклически завершается.
Что происходит после того, как контейнер завершает работу с ошибкой?

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

Изучите секцию `Last State` в выводе `describe`. Обратите внимание на:
- `Exit Code`
- `Reason`

Ненулевой exit code — это сигнал Kubernetes, что процесс завершился аварийно.

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Посмотрите секцию `Command` в манифесте. Что именно запускается?
Команда намеренно завершает процесс с кодом ошибки.

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- Контейнер запускает `exit 1` — немедленно завершается с ошибкой.
- Kubernetes видит ненулевой exit code и перезапускает контейнер.
- После нескольких быстрых рестартов Pod уходит в `CrashLoopBackOff`.
- Backoff экспоненциально растёт (10s → 20s → 40s → … → 5min).

</details>

<details>
<summary><strong>Решение</strong></summary>

```bash
kubectl -n lab apply -f ../solutions/crashloop-fixed.yaml
kubectl -n lab rollout status deploy/auth-service --timeout=120s
```

</details>

---

## Сценарий 2: catalog-api

```bash
kubectl -n lab apply -f catalog-api.yaml
kubectl -n lab get pods -l app=catalog-api -w
```

**Симптом:** Pod в статусе `Running`, но Service не маршрутизирует трафик.
`kubectl get endpoints` показывает пустой список адресов.

Начните расследование:

```bash
kubectl -n lab get pods -l app=catalog-api
kubectl -n lab get endpoints catalog-api
kubectl -n lab describe pod -l app=catalog-api
```

<details>
<summary><strong>Подсказка 1</strong></summary>

`Running` и `Ready` — разные состояния.
Посмотрите столбец `READY`: он показывает `0/1` или `1/1`?
Kubernetes включает Pod в Endpoints только при `Ready`.

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

Найдите секцию `Readiness` в выводе `describe pod`.
Какой статус пробы — `Success` или `Failure`?
Попробуйте вручную проверить, что отвечает приложение:

```bash
kubectl -n lab exec -it <pod-name> -- wget -qO- localhost/wrong
kubectl -n lab exec -it <pod-name> -- wget -qO- localhost/
```

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Сравните `readinessProbe.httpGet.path` в манифесте с реально доступными
путями приложения. Путь, по которому ходит проба, и путь, который отвечает
nginx по умолчанию, — разные.

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- `readinessProbe.httpGet.path: /wrong` — endpoint не существует.
- Nginx возвращает 404 → проба считается провалившейся.
- Pod остаётся `NotReady` → не добавляется в `Endpoints` → трафик не идёт.

</details>

<details>
<summary><strong>Решение</strong></summary>

```bash
kubectl -n lab apply -f ../solutions/readiness-fixed.yaml
kubectl -n lab rollout status deploy/catalog-api --timeout=120s
kubectl -n lab get endpoints catalog-api -o wide
```

</details>

---

## Сценарий 3: payment-worker

```bash
kubectl -n lab apply -f payment-worker.yaml
kubectl -n lab get pods -l app=payment-worker -w
```

**Симптом:** Rollout не завершается. Pod не переходит в `Running`.
Новые Pod'ы зависают сразу после создания.

Начните расследование:

```bash
kubectl -n lab get pods -l app=payment-worker
kubectl -n lab describe pod -l app=payment-worker
kubectl -n lab get events --sort-by=.lastTimestamp | tail -10
```

<details>
<summary><strong>Подсказка 1</strong></summary>

Посмотрите на статус Pod в выводе `get pods`.
Если это не `Running` и не `Pending`, это сигнал проблемы с образом.

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

В выводе `describe pod` найдите секцию `Events`.
Что пишет kubelet при попытке скачать образ?

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Найдите поле `image:` в манифесте. Проверьте тег — существует ли он
в реестре? Зайдите на hub.docker.com и проверьте доступные теги для образа.

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- Указан тег `nginx:no-such-tag`, которого нет в Docker Hub.
- Kubelet не может скачать образ → Pod уходит в `ErrImagePull`.
- После нескольких попыток статус меняется на `ImagePullBackOff`.

</details>

<details>
<summary><strong>Решение</strong></summary>

```bash
kubectl -n lab apply -f ../solutions/imagepullbackoff-fixed.yaml
kubectl -n lab rollout status deploy/payment-worker --timeout=120s
```

</details>

---

## Сценарий 4: report-generator

```bash
kubectl -n lab apply -f report-generator.yaml
kubectl -n lab get pods -l app=report-generator -w
```

**Симптом:** Pod запускается, работает несколько секунд, затем завершается.
В `describe` видны рестарты, но логи почти пусты.

Начните расследование:

```bash
kubectl -n lab get pods -l app=report-generator
kubectl -n lab describe pod -l app=report-generator
kubectl -n lab get pod -l app=report-generator \
  -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated}'
```

<details>
<summary><strong>Подсказка 1</strong></summary>

Обратите внимание на `Exit Code` в секции `Last State`.
Exit code 137 означает не обычную ошибку — это сигнал от ядра ОС.

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

В выводе `describe` найдите поле `Reason` для завершённого контейнера.
Сопоставьте с настроенными `resources.limits.memory`.

Что делает процесс с памятью?

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Посмотрите команду контейнера — Python-скрипт аллоцирует строку размером 300 МБ,
тогда как `limits.memory` установлен в 64 МБ.
Что происходит, когда процесс превышает лимит памяти?

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- Контейнер пытается выделить 300 МБ памяти при лимите 64 МБ.
- Ядро Linux убивает процесс сигналом `SIGKILL` (OOM killer).
- Kubernetes фиксирует `Exit Code: 137` и `Reason: OOMKilled`.
- Pod уходит в `CrashLoopBackOff` после нескольких итераций.

Диагностика:
```bash
kubectl -n lab get pod -l app=report-generator \
  -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}'
```

</details>

<details>
<summary><strong>Решение</strong></summary>

```bash
kubectl -n lab apply -f ../solutions/oomkilled-fixed.yaml
kubectl -n lab rollout status deploy/report-generator --timeout=120s
```

</details>
