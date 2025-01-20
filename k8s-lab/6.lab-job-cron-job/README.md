# Лабораторная работа №6: Работа с Job и CronJob в Kubernetes

## Цели лабораторной работы

1. Научиться работать с ресурсом `Job` для выполнения задач, которые завершаются после выполнения.
2. Разобраться с конфигурацией `Job` для последовательного и параллельного выполнения.
3. Понять, как настроить временные ограничения выполнения задач.
4. Изучить создание и использование ресурса `CronJob` для периодического выполнения задач.

---

## Часть 1: Создание Job для выполнения одной задачи

### Определение Job ресурса

1. Создайте файл `exporter.yaml` со следующим содержимым:

    ```yaml
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: batch-job
    spec:
      template:
        metadata:
          labels:
            app: batch-job
        spec:
          restartPolicy: OnFailure
          containers:
          - name: main
            image: luksa/batch-job
    ```

2. Примените манифест для создания Job:

    ```bash
    kubectl apply -f exporter.yaml
    ```

3. Проверьте создание ресурса Job и связанного пода:

    ```bash
    kubectl get jobs
    kubectl get pods
    ```

4. Дождитесь завершения выполнения пода и проверьте его логи:

    ```bash
    kubectl logs <имя_пода>
    ```

---

## Часть 2: Запуск нескольких экземпляров Job

### Последовательное выполнение подов

1. Создайте манифест `multi-completion-batch-job.yaml`:

    ```yaml
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: multi-completion-batch-job
    spec:
      completions: 5
      template:
        metadata:
          labels:
            app: batch-job
        spec:
          restartPolicy: OnFailure
          containers:
          - name: main
            image: luksa/batch-job
    ```

2. Примените манифест:

    ```bash
    kubectl apply -f multi-completion-batch-job.yaml
    ```

3. Наблюдайте, как поды выполняются последовательно:

    ```bash
    kubectl get pods --watch
    ```

### Параллельное выполнение подов

1. Создайте манифест `multi-completion-parallel-batch-job.yaml`:

    ```yaml
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: multi-completion-parallel-batch-job
    spec:
      completions: 5
      parallelism: 2
      template:
        metadata:
          labels:
            app: batch-job
        spec:
          restartPolicy: OnFailure
          containers:
          - name: main
            image: luksa/batch-job
    ```

2. Примените манифест:

    ```bash
    kubectl apply -f multi-completion-parallel-batch-job.yaml
    ```

3. Наблюдайте за параллельным выполнением подов:

    ```bash
    kubectl get pods --watch
    ```

---

## Часть 3: Ограничение времени выполнения Job

1. Создайте манифест `job-with-deadline.yaml`:

    ```yaml
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: job-with-deadline
    spec:
      activeDeadlineSeconds: 60
      template:
        metadata:
          labels:
            app: batch-job
        spec:
          restartPolicy: OnFailure
          containers:
          - name: main
            image: luksa/batch-job
    ```

2. Примените манифест:

    ```bash
    kubectl apply -f job-with-deadline.yaml
    ```

3. Убедитесь, что Job завершился, если время выполнения превысило 60 секунд:

    ```bash
    kubectl describe job job-with-deadline
    ```

---

## Часть 4: Использование CronJob для периодического выполнения

### Создание CronJob

1. Создайте манифест `cronjob.yaml`:

    ```yaml
    apiVersion: batch/v1beta1
    kind: CronJob
    metadata:
      name: batch-job-every-fifteen-minutes
    spec:
      schedule: "0,15,30,45 * * * *"
      jobTemplate:
        spec:
          template:
            metadata:
              labels:
                app: periodic-batch-job
            spec:
              restartPolicy: OnFailure
              containers:
              - name: main
                image: luksa/batch-job
    ```

2. Примените манифест:

    ```bash
    kubectl apply -f cronjob.yaml
    ```

3. Убедитесь, что `CronJob` создает `Job` каждые 15 минут:

    ```bash
    kubectl get cronjobs
    kubectl get jobs
    ```

### Удаление CronJob

1. Удалите ресурс CronJob:

    ```bash
    kubectl delete cronjob batch-job-every-fifteen-minutes
    ```

---

## Итог

Вы узнали:
- Как использовать `Job` для выполнения задач, которые завершаются после выполнения.
- Как запускать задачи последовательно и параллельно.
- Как ограничивать время выполнения задач.
- Как использовать `CronJob` для планирования периодического выполнения задач.

Удалите все созданные ресурсы:

```bash
kubectl delete jobs --all
kubectl delete cronjobs --all
kubectl delete pods --all
```