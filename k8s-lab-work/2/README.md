
# Лабораторная работа: Работа с Deployment и ConfigMap в Kubernetes

## Цель
Изучить работу с Deployment для управления подами и использование ConfigMap для конфигурации подов.

### Требования:
- Кластер Kubernetes с одной нодой control-plane и одной нодой worker уже настроен.
- Установленный `kubectl` для управления кластером.

## Основные задания

### 1. Работа с Deployment

#### 1.1 Создание Deployment
Deployment — это объект, который управляет ReplicaSet и гарантирует, что нужное количество подов запущено в кластере. Создайте Deployment с помощью следующего манифеста:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
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
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

Примените манифест:
```bash
kubectl apply -f deployment.yaml
```

Проверьте статус Deployment:
```bash
kubectl get deployments
kubectl get pods
```

#### 1.2 Масштабирование Deployment
Увеличьте количество реплик до 5:
```bash
kubectl scale deployment nginx-deployment --replicas=5
```

Проверьте статус:
```bash
kubectl get pods
```

#### 1.3 Обновление Deployment
Обновите версию образа контейнера до `nginx:1.16.1`:
```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.16.1
```

Проверьте состояние обновления:
```bash
kubectl rollout status deployment/nginx-deployment
```

#### 1.4 Откат Deployment
Откатите изменения до предыдущей версии:
```bash
kubectl rollout undo deployment/nginx-deployment
```

### 2. Работа с ConfigMap

#### 2.1 Создание ConfigMap
ConfigMap позволяет хранить конфигурацию в виде ключ-значение, которая может быть использована в подах. Создайте ConfigMap для настройки Nginx:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }
    }
```

Примените манифест:
```bash
kubectl apply -f configmap.yaml
```

#### 2.2 Использование ConfigMap в Pod
Создайте Pod, который использует этот ConfigMap:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod-config
spec:
  containers:
  - name: nginx
    image: nginx:latest
    volumeMounts:
    - name: nginx-config-volume
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
  volumes:
  - name: nginx-config-volume
    configMap:
      name: nginx-config
```

Примените манифест:
```bash
kubectl apply -f pod-configmap.yaml
```

#### 2.3 Проверка конфигурации
Проверьте, что конфигурация была применина:
```bash
kubectl exec -it nginx-pod-config -- cat /etc/nginx/nginx.conf
```

### 3. Практические задания

#### Задание 1: Масштабирование
1. Увеличьте количество реплик Deployment до 10 и проверьте состояние подов.

#### Задание 2: Использование ConfigMap для другой конфигурации
1. Создайте новый ConfigMap с другой конфигурацией Nginx и примените его к существующему поду через изменение манифеста.

### 4. Заключение

В этой лабораторной работе вы познакомились с объектами Deployment и ConfigMap в Kubernetes. Вы научились масштабировать, обновлять и откатывать Deployment, а также использовать ConfigMap для хранения конфигураций, которые применяются к подам.
