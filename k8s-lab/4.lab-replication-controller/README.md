# Лабораторная работа №4: Управление Pod'ами с помощью ReplicationController в Kubernetes

## Описание

ReplicationController — это ресурс Kubernetes, который обеспечивает поддержание заданного количества Pod'ов. Если Pod исчезает из-за сбоя узла или по другим причинам, ReplicationController автоматически создаёт новый Pod для его замены.

---

## Цели

1. Изучить основы работы ReplicationController.
2. Освоить создание и настройку ReplicationController.
3. Научиться управлять Pod'ами, масштабировать их количество и заменять их при удалении или сбоях.

---

## Предварительные требования

- Установленный и настроенный кластер Kubernetes (Minikube, Kind, K3s, GKE, EKS или AKS).
- Установленный инструмент `kubectl`.
- Базовые знания о Pod'ах и их конфигурации.

---

## Задания

### 1. Создание ReplicationController

1. Создайте YAML-файл `kubia-rc.yaml` со следующим содержимым:

    ```yaml
    apiVersion: v1
    kind: ReplicationController
    metadata:
      name: kubia
    spec:
      replicas: 3
      selector:
        app: kubia
      template:
        metadata:
          labels:
            app: kubia
        spec:
          containers:
            - name: kubia
              image: luksa/kubia
              ports:
                - containerPort: 8080
    ```

2. Примените этот манифест, чтобы создать ReplicationController:

    ```bash
    kubectl create -f kubia-rc.yaml
    ```

3. Убедитесь, что создано три Pod'а:

    ```bash
    kubectl get pods
    ```

---

### 2. Удаление Pod'а и его автоматическое восстановление

1. Удалите один из Pod'ов вручную:

    ```bash
    kubectl delete pod <имя_pod>
    ```

2. Проверьте, что ReplicationController создал новый Pod:

    ```bash
    kubectl get pods
    ```

---

### 3. Масштабирование Pod'ов

1. Увеличьте количество реплик Pod'ов до 5:

    ```bash
    kubectl scale rc kubia --replicas=5
    ```

2. Проверьте текущее количество Pod'ов:

    ```bash
    kubectl get pods
    ```

3. Уменьшите количество реплик до 2:

    ```bash
    kubectl scale rc kubia --replicas=2
    ```

4. Убедитесь, что количество Pod'ов уменьшилось:

    ```bash
    kubectl get pods
    ```

---

### 4. Изменение меток Pod'ов

1. Добавьте дополнительную метку к одному из Pod'ов:

    ```bash
    kubectl label pod <имя_pod> type=special
    ```

2. Проверьте, что ReplicationController продолжает управлять этим Pod'ом:

    ```bash
    kubectl get pods --show-labels
    ```

3. Измените метку `app` на другое значение, чтобы Pod вышел из-под управления ReplicationController:

    ```bash
    kubectl label pod <имя_pod> app=foo --overwrite
    ```

4. Убедитесь, что ReplicationController создал новый Pod:

    ```bash
    kubectl get pods -L app
    ```

---

### 5. Симуляция сбоя узла (необязательно)

#### Шаги

Если у вас кластер с несколькими узлами, вы можете симулировать сбой одного из узлов, чтобы проверить, как ReplicationController реагирует на потерю Pod'ов.

1. **Найдите узел с Pod'ами вашего ReplicationController.**  
   Сначала определите, какие узлы вашего кластера используются для размещения Pod'ов:

    ```bash
    kubectl get pods -o wide
    ```

   Посмотрите колонку `NODE`, чтобы узнать, на каком узле находится каждый Pod.

2. **Отключите узел вручную.**  
   Для этого войдите на узел через SSH или доступную утилиту для управления серверами, затем отключите сетевой интерфейс, чтобы симулировать потерю связи:

    ```bash
    ssh <имя_узла>
    sudo ifconfig eth0 down
    ```

   Это приведёт к тому, что Kubernetes отметит узел как `NotReady` через некоторое время.

3. **Проверьте статус узлов.**  
   Убедитесь, что узел стал недоступным:

    ```bash
    kubectl get nodes
    ```

   Узел, у которого вы отключили сеть, должен отображаться со статусом `NotReady`.

4. **Проверьте статус Pod'ов.**  
   Kubernetes подождёт некоторое время, чтобы убедиться, что это не временный сбой. После этого Pod'ы на этом узле получат статус `Unknown` или `Terminating`.

    ```bash
    kubectl get pods
    ```

5. **Наблюдайте за созданием новых Pod'ов.**  
   ReplicationController должен создать новые Pod'ы на других доступных узлах, чтобы поддерживать количество реплик.

    ```bash
    kubectl get pods -o wide
    ```

6. **Восстановите узел.**  
   Войдите на узел и включите сетевой интерфейс обратно:

    ```bash
    ssh <имя_узла>
    sudo ifconfig eth0 up
    ```

7. **Проверьте восстановление узла.**  
   Убедитесь, что узел снова доступен и имеет статус `Ready`:

    ```bash
    kubectl get nodes
    ```

8. **Проверьте статус Pod'ов.**  
   Убедитесь, что все Pod'ы находятся в работоспособном состоянии:

    ```bash
    kubectl get pods
    ```


---

## Вопросы для проверки

1. Что происходит, если изменить количество реплик в ReplicationController?
2. Как ReplicationController определяет, что требуется создать новый Pod?
3. Что произойдёт, если изменить метку `app` у Pod'а?
4. Как Kubernetes реагирует на отключение узла?

---

## Завершение работы

1. Удалите созданный ReplicationController и связанные с ним Pod'ы:

    ```bash
    kubectl delete rc kubia
    ```

2. Убедитесь, что все ресурсы удалены:

    ```bash
    kubectl get pods
    ```

---

## Результат

Вы освоили основы работы с ReplicationController, научились создавать и настраивать его, управлять Pod'ами, их масштабированием и самовосстановлением.
