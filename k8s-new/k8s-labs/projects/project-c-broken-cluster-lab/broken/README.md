# Broken Scenarios

Каталог содержит учебные поломки для тренировки диагностики.

## crashloop.yaml

```bash
kubectl -n lab apply -f crashloop.yaml
```

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Контейнер завершает работу командой `exit 1`.
- Kubernetes перезапускает контейнер по backoff-алгоритму.
- Статус переходит в `CrashLoopBackOff`.

Проверка:
```bash
kubectl -n lab get pods -l app=broken-crashloop
kubectl -n lab describe pod -l app=broken-crashloop
kubectl -n lab logs -l app=broken-crashloop --previous
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab apply -f ../solutions/crashloop-fixed.yaml
kubectl -n lab rollout status deploy/broken-crashloop --timeout=120s
```
</details>

## readiness-fail.yaml

```bash
kubectl -n lab apply -f readiness-fail.yaml
```

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Проба `readiness` проверяет неверный endpoint (`/wrong`).
- Контейнер работает, но Pod остается `NotReady`.
- Сервис не получает endpoints и не может отправлять трафик.

Проверка:
```bash
kubectl -n lab describe pod -l app=broken-readiness
kubectl -n lab get endpoints -n lab
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab apply -f ../solutions/readiness-fixed.yaml
kubectl -n lab rollout status deploy/broken-readiness --timeout=120s
```
</details>

## imagepullbackoff.yaml

```bash
kubectl -n lab apply -f imagepullbackoff.yaml
```

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Указан несуществующий image tag.
- Pod уходит в `ErrImagePull`/`ImagePullBackOff`.

Проверка:
```bash
kubectl -n lab describe pod -l app=broken-imagepull
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab apply -f ../solutions/imagepullbackoff-fixed.yaml
kubectl -n lab rollout status deploy/broken-imagepull --timeout=120s
```
</details>

## oomkilled.yaml

```bash
kubectl -n lab apply -f oomkilled.yaml
```

<details>
<summary><strong>Объяснение (раскрыть)</strong></summary>

- Контейнер пытается занять памяти больше, чем установленный `memory limit`.
- Kubelet завершает процесс, статус контейнера становится `OOMKilled`.

Проверка:
```bash
kubectl -n lab describe pod -l app=broken-oom
kubectl -n lab get pod -l app=broken-oom -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}'
```
</details>

<details>
<summary><strong>Решение (раскрыть)</strong></summary>

```bash
kubectl -n lab apply -f ../solutions/oomkilled-fixed.yaml
kubectl -n lab rollout status deploy/broken-oom --timeout=120s
```
</details>
