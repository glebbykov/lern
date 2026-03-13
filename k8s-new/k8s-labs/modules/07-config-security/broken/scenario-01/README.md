# Сценарий 01

## Симптом

Deployment создан, но Pod не запускается. Контейнер немедленно
завершается с ошибкой ещё до старта приложения.

## Запуск

```bash
kubectl -n lab apply -f deploy.yaml
kubectl -n lab get pods -l app=security-fail -w
```

## Задание

1. Выясните, на каком этапе отказывает запуск контейнера.
2. Определите, что именно kubelet отвергает.
3. Исправьте конфликт в конфигурации.

Начните:

```bash
kubectl -n lab describe pod -l app=security-fail
kubectl -n lab get events --sort-by=.lastTimestamp | tail -20
```

<details>
<summary><strong>Подсказка 1</strong></summary>

Посмотрите на Events в `describe pod`. Это не обычный crash приложения —
ошибка происходит до того, как процесс успевает запуститься.

На каком уровне: container runtime, kubelet или само приложение?

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

Найдите в манифесте секцию `securityContext`.
Какие параметры безопасности там настроены?

```bash
kubectl -n lab get deploy security-fail -o yaml | grep -A 10 "securityContext"
```

Теперь проверьте: от какого пользователя стартует стандартный образ `nginx`?

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

`runAsNonRoot: true` требует, чтобы процесс внутри контейнера
запускался с UID != 0.

Что будет, если образ по умолчанию запускается от root (UID 0),
а политика это запрещает?

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- В `securityContext` установлен `runAsNonRoot: true`.
- Образ `nginx` по умолчанию стартует от root (UID 0).
- Kubelet отклоняет запуск: нарушена политика безопасности.
- Pod попадает в `CreateContainerConfigError`.

</details>

<details>
<summary><strong>Решение</strong></summary>

Два варианта:
- Добавить `runAsUser: 101` (nginx имеет user `nginx` с UID 101).
- Использовать образ `nginxinc/nginx-unprivileged`, изначально не-root.

```bash
kubectl -n lab apply -f ../../solutions/01-run-as-nonroot-fail/deploy.yaml
kubectl -n lab rollout status deploy/security-fail --timeout=120s
```

</details>
