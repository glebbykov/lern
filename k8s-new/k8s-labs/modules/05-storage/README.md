# 05-storage

Цель: освоить тома и базовую модель PV/PVC.

## Теория (расширенная)
- `emptyDir` - ephemeral volume, привязан к жизненному циклу Pod.
- `hostPath` монтирует путь хоста и привязывает Pod к ноде; в проде рискован по безопасности и переносимости.
- `PV` описывает реальный storage-ресурс, `PVC` — запрос приложения на объем/режим доступа.
- `StorageClass` определяет provisioning policy (динамический/статический сценарий).
- `accessModes` определяет тип доступа (`RWO/RWX`), `reclaimPolicy` — поведение после удаления claim.
- В StatefulSet `volumeClaimTemplates` создает отдельный PVC для каждой реплики.

## Теоретические вопросы
1. В чем фундаментальная разница между `emptyDir` и `PVC`?
2. Почему `hostPath` опасен для production-сценариев?
3. Как связаны `PV`, `PVC` и `StorageClass`?
4. Что определяют `accessModes` и `reclaimPolicy`?
5. Как `volumeClaimTemplates` работают в StatefulSet?
6. Почему данные в stateful-сервисах нельзя привязывать только к Pod lifecycle?

## Команды для прохождения
Команды ниже запускайте из директории текущего модуля.

```bash
# 1) Сравнение emptyDir и hostPath
kubectl -n lab apply -f manifests/emptydir/pod.yaml
kubectl -n lab apply -f manifests/hostpath/pod.yaml
kubectl -n lab get pod storage-emptydir storage-hostpath -o wide

# 2) PVC
kubectl -n lab apply -f manifests/pvc/pvc.yaml
kubectl -n lab get pvc

# 3) StatefulSet + headless service
kubectl -n lab apply -f manifests/statefulset/svc-headless.yaml
kubectl -n lab apply -f manifests/statefulset/sts.yaml
kubectl -n lab get sts,pvc,pod -l app=stateful-demo

# 4) Проверка сохранности данных после пересоздания pod
kubectl -n lab delete pod stateful-demo-0
kubectl -n lab get pod stateful-demo-0 -w
```

## Порядок выполнения
1. Запустить примеры `emptyDir` и `hostPath`, сравнить поведение.
2. Создать `PVC` и убедиться в статусе `Bound`.
3. Развернуть `StatefulSet` с headless service.
4. Пересоздать Pod и проверить, что данные на PVC сохраняются.

## Практика
- Сравнить `emptyDir` и `hostPath`.
- Создать PVC и использовать в StatefulSet.
- Проверить сохранность данных после пересоздания Pod.

## Критерий готовности
Понимаете риски `hostPath` и умеете собрать StatefulSet с диском.


