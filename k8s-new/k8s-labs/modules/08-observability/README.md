# 08-observability

Цель: диагностировать деградации по событиям, логам и базовым метрикам.

## Теория (расширенная)
- Основные сигналы: events, conditions, logs, metrics.
- Events дают хронологию проблемы, conditions показывают агрегированное состояние ресурса.
- `kubectl logs` и `describe` остаются первым уровнем диагностики без внешнего стека.
- `metrics-server` дает `kubectl top` и поддерживает HPA.
- Причины деградации часто видны как комбинация: probe failures, OOM, scheduling delays, node pressure.
- Runbook должен быть линейным и воспроизводимым.

## Теоретические вопросы
1. Почему для диагностики нужны одновременно logs, metrics и events?
2. Что показывают `Conditions` и чем они отличаются от `Events`?
3. Какие ограничения у `metrics-server` по сравнению с Prometheus?
4. Как по симптомам отличить проблему приложения от проблемы кластера?
5. Зачем вести runbook и как он снижает MTTR?
6. Почему структурированные логи упрощают расследование инцидентов?

## Команды для прохождения
Команды ниже запускайте из директории текущего модуля.

```bash
# 1) Демо workload
kubectl -n lab apply -f manifests/demo/deploy.yaml
kubectl -n lab rollout status deploy/obs-demo --timeout=120s

# 2) Сигналы состояния
kubectl -n lab get pods -l app=obs-demo -o wide
kubectl -n lab describe pod -l app=obs-demo
kubectl get events -A --sort-by=.lastTimestamp | tail -n 30

# 3) Логи
kubectl -n lab logs deploy/obs-demo --tail=50

# 4) Метрики
kubectl top nodes
kubectl top pods -n lab
```

## Порядок выполнения
1. Запустить demo deployment.
2. Собрать `describe` и events для таймлайна.
3. Проверить логи контейнера.
4. Снять текущую нагрузку с `top nodes/pods`.
5. Зафиксировать вывод в runbook.

## Практика
- Events + Conditions.
- `kubectl top` (через metrics-server).
- Логи stdout/stderr и причины рестартов.

## Критерий готовности
Диагностируете инцидент без внешней магии: только средствами кластера.


