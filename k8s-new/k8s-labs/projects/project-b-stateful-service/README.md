# project-b-stateful-service

Цель: stateful-сервис с сохранением данных и регулярным бэкапом.

## Минимальный состав
- StatefulSet (например Redis)
- headless Service
- PVC
- backup CronJob
- requests/limits и PDB (добавляется при необходимости)
