
# Лабораторная работа: Введение в Kubernetes

## Цель
Изучить основные команды и объекты Kubernetes, а также выполнить практические задания.

### Требования:
- Кластер Kubernetes с одной нодой control-plane и одной нодой worker уже настроен.
- Установленный `kubectl` для управления кластером.

### 1. Основные объекты Kubernetes

#### 1.1 Создание Pod
Pod — это минимальная единица Kubernetes. Создайте Pod с помощью следующего манифеста:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:latest
```

Примените манифест:
```bash
kubectl apply -f pod.yaml
```

Проверьте статус пода:
```bash
kubectl get pods
```

#### 1.2 Сервис для Pod
Создайте сервис для вашего Pod:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: NodePort
```

Примените манифест:
```bash
kubectl apply -f service.yaml
```

Проверьте доступность сервиса:
```bash
kubectl get services
```

### 2. Практические задания

#### Задание 1: Изучение логов
1. Посмотрите логи созданного Pod:
   ```bash
   kubectl logs nginx-pod
   ```
2. Ответьте на вопрос: для чего могут быть полезны логи в Kubernetes?

#### Задание 2: Рестарт Pod
1. Перезапустите Pod:
   ```bash
   kubectl delete pod nginx-pod
   kubectl apply -f pod.yaml
   ```
2. Ответьте на вопрос: как перезапуск Pod отличается от перезапуска контейнера?

#### Задание 3: Репликация Pod
1. Создайте манифест для ReplicaSet с 3 репликами:
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
```

2. Примените манифест и проверьте статус:
   ```bash
   kubectl apply -f replicaset.yaml
   kubectl get pods
   ```

#### Задание 4: Обновление образа
1. Обновите образ nginx в ReplicaSet до версии `nginx:1.19`:
   ```bash
   kubectl set image replicaset/nginx-replicaset nginx=nginx:1.19
   ```
2. Проверьте состояние обновления:
   ```bash
   kubectl rollout status replicaset/nginx-replicaset
   ```

#### Задание 5: Откат изменений
1. Откатите изменения, вернув предыдущую версию образа:
   ```bash
   kubectl rollout undo replicaset/nginx-replicaset
   ```

### 3. Теоретические вопросы для закрепления

1. Чем отличаются Pod и ReplicaSet?
2. Что такое сервис в Kubernetes и зачем он нужен?
3. Как Kubernetes обеспечивает автоматическое масштабирование подов?

### 4. Заключение

Эта лабораторная работа познакомила вас с основными объектами Kubernetes, включая Pod, ReplicaSet и Service. Вы научились инициализировать кластер, создавать и управлять объектами Kubernetes, а также выполнять базовые операции, такие как логирование, рестарт, обновление и откат подов.
