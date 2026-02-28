# 04-statefulset-basics

## Цель
Понять стабильные имена Pod и работу headless Service.

## Проверка
- Pod имена фиксированы (`stateful-demo-0`, ...).
- DNS имя Pod доступно через headless Service.
- PVC создаются автоматически при `volumeClaimTemplates`.
