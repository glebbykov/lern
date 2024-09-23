
# Лабораторная работа: Деплой приложения в Kubernetes с помощью Helm 3

## Цель
Научиться деплоить приложение в кластер Kubernetes с использованием Helm 3 и автоматизировать процесс деплоя с помощью Ansible, а также настроить файлы шаблонов для правильной конфигурации Kubernetes-ресурсов.

## Требования
- Установленный Helm 3
- Доступ к Kubernetes-кластеру
- Установленный и настроенный Ansible для выполнения задач на узлах

## Шаги выполнения

### Шаг 1: Установка Helm 3

1. Убедитесь, что Helm 3 установлен. Для этого выполните команду:

    ```bash
    helm version
    ```

    Вы должны увидеть вывод с версией Helm 3, например:

```bash
    version.BuildInfo{Version:"v3.16.1", GitCommit:"<commit-hash>", GitTreeState:"clean", GoVersion:"go1.16.8"}
```

2. Если Helm не установлен, установите его, следуя [официальной документации](https://helm.sh/docs/intro/install/).

### Шаг 2: Создание чарта Helm

1. Для создания нового Helm-чарта выполните следующую команду:

```bash
    helm create myapp
```

Это создаст структуру каталога для вашего чарта в папке `myapp`.

1. Измените файлы шаблонов в каталоге `myapp/templates` для настройки Kubernetes-ресурсов.

### Шаг 3: Настройка шаблонов Helm

1. Откройте файл `deployment.yaml` в каталоге `myapp/templates`.

2. Настройте его следующим образом, чтобы он деплоил простое приложение на основе Nginx:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-nginx
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: nginx
          image: nginx:1.19.0
          ports:
            - containerPort: 80
```

3. Откройте файл `service.yaml` и настройте его для создания сервиса, который обеспечит доступ к приложению:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-nginx-service
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: {{ .Release.Name }}
```

4. Убедитесь, что файл `values.yaml` содержит настройки для ресурсов:

```yaml
replicaCount: 2
image:
  repository: nginx
  tag: "1.19.0"
service:
  type: NodePort
  port: 80

serviceAccount:
  create: true      
  name: ""       
  automount: true
    
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: "chart-example.local"
      paths:
        - path: /
          pathType: Prefix
  tls: []

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### Шаг 4: Установка приложения в Kubernetes

1. Примените чарт Helm для деплоя приложения в кластер:

    ```bash
    helm install myapp ./myapp
    ```

    Здесь `myapp` — это имя вашего релиза, а `./myapp` — путь к директории с чартом.

2. Проверьте статус релиза:

    ```bash
    helm status myapp
    ```

3. Убедитесь, что приложение успешно запущено:

    ```bash
    kubectl get pods
    ```

    Должны быть видны поды, запущенные вашим приложением.

### Шаг 5: Автоматизация деплоя с использованием Ansible

1. Создайте плейбук Ansible `deploy_helm.yml` со следующим содержимым:

    ```yaml
    ---
    - hosts: localhost
      tasks:
        - name: Установить приложение с помощью Helm
          command: helm install myapp ./myapp
          args:
            chdir: /path/to/your/helm/chart
    ```

2. Запустите плейбук Ansible:

    ```bash
    ansible-playbook deploy_helm.yml
    ```

    Убедитесь, что приложение успешно деплоится в кластер.

### Шаг 6: Обновление приложения

1. Внесите изменения в чарт Helm (например, обновите версию образа контейнера или настройку автоскейлинга в файле `values.yaml`).
2. Примените изменения с помощью команды:

    ```bash
    helm upgrade myapp ./myapp
    ```

3. Убедитесь, что обновление прошло успешно:

```bash
helm status myapp
```

### Шаг 7: Удаление приложения

Для удаления приложения из кластера выполните команду:

```bash
helm uninstall myapp
```

### Заключение

Вы научились деплоить приложение в Kubernetes с помощью Helm 3, настраивать шаблоны для различных ресурсов Kubernetes и автоматизировать процесс деплоя с помощью Ansible.
