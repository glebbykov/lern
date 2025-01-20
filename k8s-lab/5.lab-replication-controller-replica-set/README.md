# Лабораторная работа №5: Работа с ReplicationController и ReplicaSet

## Цели лабораторной работы

1. Изучить, как менять шаблон подов в `ReplicationController`.
2. Научиться горизонтальному масштабированию подов.
3. Понять, как удалять ReplicationController и его поды.
4. Познакомиться с использованием ReplicaSet вместо ReplicationController.
5. Ознакомиться с использованием DaemonSet для запуска подов на всех узлах кластера.

---

## Часть 1: Изменение шаблона подов в ReplicationController

1. Откройте ReplicationController для редактирования:

    ```bash
    kubectl edit rc kubia
    ```

2. Добавьте новый лейбл к секции `metadata` в шаблоне подов. Пример:

    ```yaml
    template:
      metadata:
        labels:
          app: kubia
          version: v2
    ```

3. Сохраните изменения. Kubernetes выведет сообщение об успешном обновлении.

4. Убедитесь, что лейблы у существующих подов не изменились:

    ```bash
    kubectl get pods --show-labels
    ```

5. Удалите один из подов:

    ```bash
    kubectl delete pod <имя_пода>
    ```

6. Проверьте, что новый под был создан с обновлённым шаблоном:

    ```bash
    kubectl get pods --show-labels
    ```

---

## Часть 2: Масштабирование подов

### Горизонтальное масштабирование через `kubectl scale`

1. Увеличьте количество реплик до 10:

    ```bash
    kubectl scale rc kubia --replicas=10
    ```

2. Проверьте, что было создано 10 подов:

    ```bash
    kubectl get rc
    ```

3. Уменьшите количество реплик обратно до 3:

    ```bash
    kubectl scale rc kubia --replicas=3
    ```

### Масштабирование через редактирование

1. Откройте ReplicationController для редактирования:

    ```bash
    kubectl edit rc kubia
    ```

2. Измените значение поля `replicas` на 10:

    ```yaml
    spec:
      replicas: 10
    ```

3. Сохраните изменения. Kubernetes масштабирует поды автоматически.

---

## Часть 3: Удаление ReplicationController

1. Удалите ReplicationController, оставив поды без управления:

    ```bash
    kubectl delete rc kubia --cascade=false
    ```

2. Проверьте, что поды продолжают работать:

    ```bash
    kubectl get pods
    ```

3. Удалите оставшиеся поды вручную:

    ```bash
    kubectl delete pod <имя_пода>
    ```

---

## Часть 4: Работа с ReplicaSet

### Создание ReplicaSet

1. Создайте файл `kubia-replicaset.yaml` со следующим содержимым:

    ```yaml
    apiVersion: apps/v1
    kind: ReplicaSet
    metadata:
      name: kubia
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: kubia
      template:
        metadata:
          labels:
            app: kubia
        spec:
          containers:
          - name: kubia
            image: luksa/kubia
    ```

2. Примените файл:

    ```bash
    kubectl apply -f kubia-replicaset.yaml
    ```

3. Проверьте созданные ресурсы:

    ```bash
    kubectl get rs
    kubectl get pods
    ```

### Использование расширенных селекторов

1. Модифицируйте селектор ReplicaSet, используя `matchExpressions`:

    ```yaml
    selector:
      matchExpressions:
        - key: app
          operator: In
          values:
            - kubia
    ```

2. Примените изменения и проверьте работу нового селектора.

---

## Часть 5: Работа с DaemonSet

### Создание DaemonSet

1. Создайте файл `ssd-monitor-daemonset.yaml` со следующим содержимым:

    ```yaml
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      name: ssd-monitor
    spec:
      selector:
        matchLabels:
          app: ssd-monitor
      template:
        metadata:
          labels:
            app: ssd-monitor
        spec:
          nodeSelector:
            disk: ssd
          containers:
          - name: main
            image: luksa/ssd-monitor
    ```

2. Примените файл:

    ```bash
    kubectl apply -f ssd-monitor-daemonset.yaml
    ```

3. Проверьте DaemonSet:

    ```bash
    kubectl get ds
    kubectl get pods
    ```

### Добавление лейблов узлу

1. Добавьте лейбл узлу:

    ```bash
    kubectl label node <имя_узла> disk=ssd
    ```

2. Проверьте, что DaemonSet создал под на узле:

    ```bash
    kubectl get pods -o wide
    ```

3. Удалите лейбл узла и проверьте, что под был удалён:

    ```bash
    kubectl label node <имя_узла> disk=hdd --overwrite
    kubectl get pods
    ```

---

## Итог

Вы научились:
- Изменять шаблоны подов.
- Масштабировать поды.
- Удалять ReplicationController с сохранением подов.
- Работать с ReplicaSet.
- Использовать DaemonSet для запуска подов на всех узлах.

Сохраните свои изменения и удалите все созданные ресурсы:

```bash
kubectl delete rc,rs,ds --all
kubectl delete pods --all
```