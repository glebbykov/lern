# Сценарий 01

## Симптом

Argo CD Application создан, но синхронизация не выполняется —
статус приложения `Unknown` или `OutOfSync` с ошибкой.

## Запуск

```bash
kubectl apply -f app.yaml
kubectl -n argocd get application demo-app
```

## Задание

1. Выясните, почему Argo CD не может синхронизировать приложение.
2. Найдите некорректный параметр в конфигурации Application.
3. Исправьте и подтвердите успешную синхронизацию.

Начните:

```bash
kubectl -n argocd get application demo-app -o yaml
kubectl -n argocd describe application demo-app
```

<details>
<summary><strong>Подсказка 1</strong></summary>

Argo CD для синхронизации должен найти манифесты в репозитории.
Посмотрите на статус и сообщение об ошибке:

```bash
kubectl -n argocd get application demo-app -o jsonpath='{.status.conditions}'
```

Что именно не находит Argo CD?

</details>

<details>
<summary><strong>Подсказка 2</strong></summary>

В `spec.source` указан путь к манифестам в репозитории.
Проверьте поле `path` в `app.yaml`:

```bash
kubectl -n argocd get application demo-app -o jsonpath='{.spec.source.path}'
```

Существует ли этот путь в репозитории?

</details>

<details>
<summary><strong>Подсказка 3</strong></summary>

Правильный путь к чарту для этого сценария:
`k8s-new/k8s-labs/modules/09-helm-gitops/charts/demo-app`

Что написано в `app.yaml`? Чем отличается?

</details>

<details>
<summary><strong>Объяснение</strong></summary>

- `spec.source.path` указывает на несуществующий путь в репозитории.
- Argo CD не может найти chart/manifests для рендера.
- Синхронизация падает с `path not found` или ошибкой рендера.

</details>

<details>
<summary><strong>Решение</strong></summary>

Исправить `spec.source.path` на корректный путь к чарту.

```bash
kubectl apply -f ../../solutions/01-argocd-path/app.yaml
```

</details>
