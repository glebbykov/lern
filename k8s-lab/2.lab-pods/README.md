
# Лабораторная работа: Управление Pods в Kubernetes

## Цели

- Освоить базовые операции с Pods: создание, запуск, остановка.
- Изучить способы организации ресурсов с помощью меток и аннотаций.
- Ознакомиться с работой в разных Namespace.
- Развернуть Pods на выбранных узлах кластера.

---

## Задания

### 1. Создание Pods из YAML-манифеста

1. Создайте файл `pod-example.yaml` с содержимым:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: example-pod
     labels:
       app: example
   spec:
     containers:
     - name: example-container
       image: nginx:latest
       ports:
       - containerPort: 80
   ```
2. Запустите Pod с помощью команды:
   ```bash
   kubectl apply -f pod-example.yaml
   ```
3. Проверьте статус Pod:
   ```bash
   kubectl get pods
   ```
4. Ответьте на вопросы:
   - Какой статус отображается у Pod сразу после создания?
   - Как узнать IP-адрес Pod?

---

### 2. Изучение Pod через команду describe

1. Используйте команду:
   ```bash
   kubectl describe pod example-pod
   ```
2. Обратите внимание на:
   - Метаданные Pod (имя, метки, аннотации);
   - События, связанные с запуском Pod.
3. Ответьте на вопросы:
   - Что происходит, если контейнер внутри Pod завершает свою работу с ошибкой?
   - Как можно добавить аннотации к существующему Pod?

---

### 3. Работа с метками и селекторами

1. Добавьте метку к существующему Pod:
   ```bash
   kubectl label pod example-pod environment=production
   ```
2. Проверьте, что метка добавлена:
   ```bash
   kubectl get pods --show-labels
   ```
3. Выведите список Pod, используя селектор меток:
   ```bash
   kubectl get pods -l environment=production
   ```
4. Ответьте на вопросы:
   - Чем отличаются метки от аннотаций?
   - Можно ли изменить метки у работающего Pod?

---

### 4. Использование Namespace

1. Создайте новый Namespace:
   ```bash
   kubectl create namespace dev
   ```
2. Запустите Pod в новом Namespace:
   ```bash
   kubectl apply -f pod-example.yaml -n dev
   ```
3. Выведите список Pod в Namespace `dev`:
   ```bash
   kubectl get pods -n dev
   ```
4. Удалите Pod в Namespace `dev`:
   ```bash
   kubectl delete pod example-pod -n dev
   ```
5. Ответьте на вопросы:
   - Какие ресурсы не организуются по Namespace?
   - Как переключиться на другой Namespace по умолчанию?

---

### 5. Назначение Pods определенным узлам

1. Узнайте список узлов в вашем кластере:
   ```bash
   kubectl get nodes
   ```
2. Добавьте метку к одному из узлов:
   ```bash
   kubectl label node <имя_узла> gpu=true
   ```
3. Создайте манифест Pod с nodeSelector:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: gpu-pod
   spec:
     nodeSelector:
       gpu: "true"
     containers:
     - name: gpu-container
       image: nvidia/cuda:11.2.2-runtime-ubuntu20.04
   ```
4. Запустите Pod и проверьте, на каком узле он работает:
   ```bash
   kubectl apply -f pod-gpu.yaml
   kubectl get pod gpu-pod -o wide
   ```
5. Ответьте на вопросы:
   - Как убедиться, что Pod был назначен на правильный узел?
   - Что произойдет, если в кластере нет узлов с подходящей меткой?

---

### 6. Остановка и удаление Pods

1. Удалите Pod по имени:
   ```bash
   kubectl delete pod example-pod
   ```
2. Удалите все Pods с меткой `app=example`:
   ```bash
   kubectl delete pod -l app=example
   ```
3. Удалите все Pods в Namespace `default`:
   ```bash
   kubectl delete pods --all
   ```
4. Ответьте на вопросы:
   - Как остановить Pod, созданный через Replication Controller?
   - Что происходит с ресурсами, связанными с Pod, после его удаления?

---

### 7. Дополнительное задание

1. Создайте Pod, используя аннотацию для указания автора:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: annotated-pod
     annotations:
       author: "<ваше_имя>"
   spec:
     containers:
     - name: annotated-container
       image: httpd:latest
   ```
2. Изучите содержимое Pod с аннотацией:
   ```bash
   kubectl describe pod annotated-pod
   ```
3. Ответьте на вопросы:
   - Как использовать аннотации для управления жизненным циклом Pods?
   - Чем отличаются аннотации от меток в Kubernetes?

---

### 8. Дополнительные задания

1. Создайте Pod с использованием ConfigMap для передачи переменных среды внутрь контейнера.
2. Настройте лимиты ресурсов (CPU и память) для Pod.
3. Создайте Pod с несколькими контейнерами, взаимодействующими через общий Volume.
4. Изучите логи Pod, который завершился с ошибкой, и определите причину сбоя. Используйте следующий манифест для создания Pod, который завершится с ошибкой:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-error-pod
spec:
  containers:
  - name: misconfigured-container
    image: busybox
    command: ["/bin/sh", "-c", "echo $UNDEFINED_ENV_VAR && sleep 3600"]
    env:
    - name: CORRECT_ENV_VAR
      value: "Hello World"
```

5. Используйте команды для получения списка Pods, которые работают в конкретном Namespace.
6. Настройте автоматическое масштабирование для Pods на основе загрузки CPU.
7. Удалите Pod с использованием Grace Period и проверьте, как это влияет на завершение работы контейнера.

---

## Вопросы для закрепления

1. Чем Pods отличаются от контейнеров?
2. Какое назначение у меток и аннотаций в Kubernetes?
3. Как назначить Pods определенным узлам в кластере?
4. Какие ресурсы Kubernetes не организуются по Namespace?
5. Что происходит с контейнерами внутри Pod при его удалении?
6. Как можно проверить, что Pod находится в состоянии Running?
