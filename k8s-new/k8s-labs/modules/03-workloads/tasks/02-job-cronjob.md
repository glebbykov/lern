# 02-job-cronjob

## Шаги
- Запустить Job и убедиться, что он завершился успешно.
- Запустить CronJob и дождаться хотя бы одного Job.
- Проверить события при проблеме со стартом (image/resources).

## Проверка
```bash
kubectl -n lab get job
kubectl -n lab get cronjob
kubectl -n lab get events --sort-by=.lastTimestamp
```
