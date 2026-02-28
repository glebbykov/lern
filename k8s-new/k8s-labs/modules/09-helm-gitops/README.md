# 09-helm-gitops

Цель: упаковать приложение как chart и синхронизировать через GitOps.

## Теория (расширенная)
- Helm chart — параметризованный пакет Kubernetes-манифестов.
- `values.yaml` хранит входные параметры, templates рендерятся в финальный YAML.
- `helm lint` и `helm template` позволяют проверить chart до деплоя.
- GitOps: Git — источник истины, контроллер постоянно выравнивает cluster state под Git state.
- Argo CD `Application` описывает что синхронизировать, `AppProject` — границы и политики доступа.
- Типовые причины sync fail: неверный path, невалидный YAML, отсутствующий namespace/CRD, RBAC-ограничения.

## Теоретические вопросы
1. Какие обязательные элементы структуры Helm chart?
2. Как `values.yaml` и templates формируют итоговый манифест?
3. Чем `helm lint` и `helm template` полезны до деплоя?
4. В чем суть GitOps-подхода и что является source of truth?
5. Почему возникает drift и как GitOps-контроллер его исправляет?
6. Какую роль в Argo CD играют `Application` и `AppProject`?

## Команды для прохождения
Команды ниже запускайте из директории текущего модуля.

```bash
# 1) Проверка chart
cd charts/demo-app
helm lint .
helm template demo-app . > /tmp/demo-app-rendered.yaml
cd ../..

# 2) Установка Helm release
helm upgrade --install demo-app ./charts/demo-app -n lab --create-namespace
kubectl -n lab get deploy,svc,ingress

# 3) GitOps manifests (dry-run)
kubectl apply --dry-run=client -f ./gitops/argocd/project.yaml
kubectl apply --dry-run=client -f ./gitops/argocd/app.yaml
```

## Порядок выполнения
1. Прогнать `helm lint`.
2. Срендерить шаблоны через `helm template` и проверить YAML.
3. Установить release в `lab`.
4. Проверить созданные ресурсы и доступность.
5. Валидировать Argo CD manifests и подготовить sync.

## Практика
- Helm chart: Deployment/Service/Ingress/ConfigMap.
- Параметры через `values.yaml`.
- Argo CD Application + Project.

## Критерий готовности
Разворачиваете приложение из пустого namespace одной командой Helm и через GitOps sync.
