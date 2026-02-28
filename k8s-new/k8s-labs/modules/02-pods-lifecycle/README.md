# 02-pods-lifecycle

Цель: понять жизненный цикл Pod, роль initContainer и probes.

## Теория (расширенная)
- Жизненный цикл Pod: `Pending -> Running -> Succeeded/Failed`; внутри важны состояния контейнера (`Waiting/Running/Terminated`).
- `initContainers` запускаются последовательно до старта основных контейнеров.
- `readinessProbe` управляет попаданием Pod в Service endpoints.
- `livenessProbe` лечит зависание путем restart контейнера.
- `startupProbe` защищает медленно стартующие приложения от преждевременного kill.
- Requests/limits применяются scheduler и cgroups; превышение памяти приводит к `OOMKilled`.
- QoS (`Guaranteed/Burstable/BestEffort`) влияет на eviction при memory pressure.

## Теоретические вопросы
1. Зачем `initContainers` отделены от обычных контейнеров Pod?
2. В чем практическая разница между `readinessProbe`, `livenessProbe` и `startupProbe`?
3. Почему `readiness` влияет на трафик, а `liveness` на рестарты?
4. Как requests/limits связаны с QoS-классами Pod?
5. Что означает `OOMKilled` и на каком уровне это происходит?
6. Как `RestartPolicy` влияет на поведение workload в разных типах ресурсов?

## Команды для прохождения
Команды ниже запускайте из директории текущего модуля.

```bash
# 1) InitContainer сценарий
kubectl -n lab apply -f manifests/initcontainer/pod.yaml
kubectl -n lab get pod init-wait-dns -w
kubectl -n lab logs init-wait-dns -c wait-dns
kubectl -n lab logs init-wait-dns -c app --tail=20

# 2) Пробы (исправный вариант)
kubectl -n lab apply -f manifests/probes/deploy.yaml
kubectl -n lab apply -f manifests/probes/svc.yaml
kubectl -n lab rollout status deploy/probe-demo --timeout=120s

# 3) Пробы (сломанный readiness)
kubectl -n lab apply -f broken/02-readiness-fail/deploy.yaml
kubectl -n lab describe pod -l app=probe-demo
kubectl -n lab get endpoints probe-demo -o wide

# 4) Возврат решения
kubectl -n lab apply -f solutions/02-readiness-fail/deploy.yaml
kubectl -n lab rollout status deploy/probe-demo --timeout=120s

# 5) Диагностика OOM (пример)
kubectl -n lab get pod
kubectl -n lab describe pod <pod-with-oom>
kubectl -n lab get pod <pod-with-oom> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
```

## Порядок выполнения
1. Запустить Pod с initContainer и проверить порядок запуска.
2. Поднять deployment с пробами в рабочем состоянии.
3. Намеренно сломать readiness и посмотреть endpoints/events.
4. Применить исправление и убедиться, что Pod снова Ready.
5. Отдельно воспроизвести/проанализировать `OOMKilled`.

## Практика
- initContainer: дождаться DNS и подготовить файл в `emptyDir`.
- liveness/readiness: увидеть влияние на трафик и рестарты.
- requests/limits: воспроизвести `OOMKilled`.

## Критерий готовности
Объясняете разницу `liveness` и `readiness` на практических симптомах.


