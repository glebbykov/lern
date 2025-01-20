# Лабораторная работа №3: Управление Pod'ами в Kubernetes и их обеспечивающие контроллеры

## Описание

Данная лабораторная работа охватывает ключевые аспекты управления Pod'ами в Kubernetes, включая механизмы самовосстановления при сбоях, использование Liveness Probes, а также настройку ресурсов для поддержания Pod'ов на случай сбоя узлов. Основная цель работы — научиться управлять Pod'ами через контроллеры, такие как ReplicationController, и обеспечивать их автоматическое восстановление.

## Цели

1. **Освоить** принципы работы Liveness Probes для проверки состояния контейнеров.
2. **Научиться** добавлять liveness-пробы в Pod'ы и анализировать их поведение.
3. **Изучить**, как Kubernetes управляет Pod'ами через контроллеры, такие как ReplicationController.
4. **Разобраться** в механизмах самовосстановления Pod'ов при сбоях на уровне узлов и контейнеров.

---

## Предварительные требования

- Настроенный кластер Kubernetes (локально через Minikube, Kind или K3s, либо в облаке: GKE, EKS, AKS и т.д.).
- Установленный и настроенный клиентский инструмент `kubectl`.
- Понимание базовых операций с Pod'ами (создание, удаление, просмотр логов).

---

## 1. Знакомство с Liveness Probes

### Теоретическая часть

Kubernetes использует liveness-пробы для проверки состояния контейнера. Если проба показывает, что контейнер не работает, Kubernetes перезапускает его. Пробы бывают трёх типов:

1. **HTTP GET** — выполняет HTTP-запрос на указанный адрес. Если код ответа 2xx или 3xx, проба считается успешной.
2. **TCP Socket** — пытается установить TCP-соединение с указанным портом контейнера.
3. **Exec** — выполняет команду внутри контейнера и проверяет её код возврата (0 — успешный).

### Практическая часть: Настройка Liveness Probe

1. Создайте Pod с Liveness Probe:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubia-liveness
spec:
  containers:
    - name: kubia
      image: luksa/kubia-unhealthy
      ports:
        - containerPort: 8080
      livenessProbe:
        httpGet:
          path: /
          port: 8080
        initialDelaySeconds: 5
        periodSeconds: 10
```

2. Примените манифест:

```bash
kubectl apply -f kubia-liveness.yaml
```

3. Проверьте состояние Pod'а:

```bash
kubectl get pod kubia-liveness
kubectl describe pod kubia-liveness
```

4. Посмотрите логи контейнера:

```bash
kubectl logs kubia-liveness
kubectl logs kubia-liveness --previous
```

### Вопросы для обсуждения

- Какие типы liveness-проб поддерживает Kubernetes?
- Как настроить задержку перед запуском проб (initialDelaySeconds)? Почему это важно?
- Что происходит с Pod'ом, если liveness-проба трижды подряд не проходит?

---

## 2. Управление Pod'ами через ReplicationController

### Теоретическая часть

ReplicationController отвечает за поддержание заданного количества реплик Pod'ов в кластере. Если один из Pod'ов выходит из строя, контроллер автоматически создаёт новый.

### Практическая часть

1. Создайте ReplicationController:

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: kubia-rc
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

2. Примените манифест:

```bash
kubectl apply -f kubia-rc.yaml
```

3. Проверьте состояние Pod'ов:

```bash
kubectl get pods
kubectl get rc
```

4. Удалите один из Pod'ов:

```bash
kubectl delete pod <pod-name>
```

5. Убедитесь, что ReplicationController создал новый Pod взамен удалённого:

```bash
kubectl get pods
```

6. Масштабируйте количество реплик:

```bash
kubectl scale rc kubia-rc --replicas=5
kubectl get pods
```

### Вопросы для обсуждения

- Как ReplicationController определяет, что Pod «вышел из строя»?
- Что произойдёт, если вручную изменить количество Pod'ов, не изменяя настройки ReplicationController?

---

## 3. Анализ состояния контейнеров

1. Посмотрите подробную информацию о Pod'е:

```bash
kubectl describe pod kubia-liveness
```

2. Изучите причину перезапуска контейнера:

- Проверьте код завершения контейнера (например, 137 — SIGKILL).
- Найдите причину перезапуска в разделе событий (Events).

3. Используйте `--previous` для анализа логов перезапущенного контейнера:

```bash
kubectl logs kubia-liveness --previous
```

### Вопросы для обсуждения

- Как интерпретировать коды завершения контейнера?
- Что означают exit codes 137 и 143?

---

## 4. Лучшие практики для Liveness Probes

1. Настраивайте `initialDelaySeconds` для учёта времени запуска приложения.
2. Минимизируйте нагрузку, создаваемую пробами (например, избегайте тяжёлых операций).
3. Избегайте проверки внешних зависимостей (например, баз данных) в liveness-пробах.
4. Используйте специализированные URL, такие как `/health`, для проверки состояния приложения.

---

## Завершение работы

1. Удалите созданные объекты:

```bash
kubectl delete pod kubia-liveness
kubectl delete rc kubia-rc
```

2. Убедитесь, что в кластере не осталось лишних ресурсов:

```bash
kubectl get all
```

---

## Результаты

После выполнения этой лабораторной работы вы научились:

- Настраивать liveness-пробы для Pod'ов.
- Анализировать причины перезапуска контейнеров.
- Управлять Pod'ами через ReplicationController.

Эти навыки помогут вам обеспечить стабильность и высокую доступность приложений, развернутых в Kubernetes.
