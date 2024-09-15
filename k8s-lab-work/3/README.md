
# Лабораторная работа: Работа с PersistentVolume и PersistentVolumeClaim в Kubernetes

## Цель
Изучить работу с постоянным хранилищем данных с использованием объектов PersistentVolume (PV) и PersistentVolumeClaim (PVC) в Kubernetes.

### Требования:
- Кластер Kubernetes с одной нодой control-plane и одной нодой worker уже настроен.
- Установленный `kubectl` для управления кластером.

## Основные задания

### 1. Работа с PersistentVolume (PV)

#### 1.1 Создание PersistentVolume
PersistentVolume предоставляет хранилище для подов. Создайте PersistentVolume с помощью следующего манифеста:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-volume
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
```

Примените манифест:
```bash
kubectl apply -f pv.yaml
```

Проверьте статус PV:
```bash
kubectl get pv
```

### 2. Работа с PersistentVolumeClaim (PVC)

#### 2.1 Создание PersistentVolumeClaim
PersistentVolumeClaim — это запрос на ресурс хранилища. Создайте PVC, который запросит 500Mi постоянного хранилища:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

Примените манифест:
```bash
kubectl apply -f pvc.yaml
```

Проверьте статус PVC:
```bash
kubectl get pvc
```

### 3. Использование PVC в Pod

#### 3.1 Создание Pod с использованием PVC
Создайте Pod, который использует PersistentVolumeClaim для хранения данных:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod-pvc
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - mountPath: "/usr/share/nginx/html"
      name: pvc-storage
  volumes:
  - name: pvc-storage
    persistentVolumeClaim:
      claimName: pvc-claim
```

Примените манифест:
```bash
kubectl apply -f pod-pvc.yaml
```

Проверьте статус пода:
```bash
kubectl get pods
```

#### 3.2 Запись данных в хранилище
Запишите данные в хранилище:
```bash
kubectl exec -it nginx-pod-pvc -- /bin/bash -c "echo 'Hello, Kubernetes!' > /usr/share/nginx/html/index.html"
```

#### 3.3 Проверка данных
Проверьте, что данные сохранились:
```bash
kubectl exec -it nginx-pod-pvc -- cat /usr/share/nginx/html/index.html
```

### 4. Практические задания

#### Задание 1: Изменение PVC
1. Увеличьте запрос PVC до 1Gi и проверьте состояние.

#### Задание 2: Проверка постоянства данных
1. Перезапустите Pod и проверьте, что данные, записанные ранее, остались на месте.

### 5. Заключение

В этой лабораторной работе вы научились работать с постоянным хранилищем данных в Kubernetes, используя объекты PersistentVolume и PersistentVolumeClaim. Вы научились создавать PV и PVC, использовать их в подах, записывать и проверять данные.
