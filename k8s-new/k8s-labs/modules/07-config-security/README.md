# 07-config-security

Цель: безопасно передавать конфиг приложению и ограничивать права.

## Теория (расширенная)
- `ConfigMap` хранит несекретный runtime-конфиг, `Secret` — чувствительные данные.
- Конфиг как env фиксируется на момент старта контейнера; config как volume обновляется иначе.
- Каждый Pod запускается от ServiceAccount, который определяет доступ к API.
- RBAC: `Role/ClusterRole` задает права, `RoleBinding/ClusterRoleBinding` связывает права с субъектом.
- Принцип least privilege: выдавать минимальные права и только в нужном namespace.
- `securityContext` снижает риск эскалации: non-root, no privilege escalation, readonly root fs.

## Теоретические вопросы
1. Когда использовать `ConfigMap`, а когда `Secret`?
2. Чем отличается инъекция конфигурации через env и через volume?
3. Как `ServiceAccount` связан с доступом Pod к Kubernetes API?
4. В чем отличие `Role` от `ClusterRole` и `RoleBinding` от `ClusterRoleBinding`?
5. Какие риски несет избыточный RBAC (`*` на все ресурсы)?
6. Какие минимальные поля `securityContext` стоит включать по умолчанию?

## Команды для прохождения
Команды ниже запускайте из директории текущего модуля.

```bash
# 1) ConfigMap + приложение
kubectl -n lab apply -f manifests/config/cm.yaml
kubectl -n lab apply -f manifests/config/deploy.yaml
kubectl -n lab get cm,deploy,pod -l app=config-demo

# 2) Secret + приложение
kubectl -n lab apply -f manifests/secrets/secret.yaml
kubectl -n lab apply -f manifests/secrets/deploy.yaml
kubectl -n lab get secret,deploy,pod -l app=secret-demo

# 3) RBAC
kubectl -n lab apply -f manifests/rbac/sa.yaml
kubectl -n lab apply -f manifests/rbac/role.yaml
kubectl -n lab apply -f manifests/rbac/rolebinding.yaml
kubectl -n lab auth can-i get pods --as=system:serviceaccount:lab:pod-reader
kubectl -n lab auth can-i delete pods --as=system:serviceaccount:lab:pod-reader
```

## Порядок выполнения
1. Развернуть ConfigMap-сценарий и проверить env/конфиг.
2. Добавить Secret-сценарий и убедиться, что секреты не утекли в логи.
3. Применить RBAC и проверить `can-i` для ServiceAccount.
4. Проверить securityContext у pod через `describe`.

## Практика
- ConfigMap и Secret как env/volumes.
- ServiceAccount и RBAC на чтение Pods.
- SecurityContext (`runAsNonRoot`, `readOnlyRootFilesystem`).


