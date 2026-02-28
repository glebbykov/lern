# 06-scheduling

Цель: контролировать, куда попадают Pod и сколько ресурсов они потребляют.

## Теория (расширенная)
- Scheduler фильтрует ноды по жестким ограничениям и ранжирует кандидатов по soft-правилам.
- Labels + `nodeSelector` задают простой hard placement.
- `taints` защищают ноды от нежелательной нагрузки, `tolerations` позволяют исключения.
- Affinity/anti-affinity задает гибкие правила co-location и anti-co-location.
- `ResourceQuota` ограничивает суммарные ресурсы namespace.
- `LimitRange` задает defaults и пределы requests/limits для контейнеров.
- На малых нодах quotas/limits критичны для предотвращения resource starvation.

## Теоретические вопросы
1. Как scheduler выбирает ноду: фильтрация и ранжирование?
2. Когда достаточно `nodeSelector`, а когда нужна `affinity/anti-affinity`?
3. Как `taints` и `tolerations` помогают защитить control-plane/спец-ноды?
4. В чем разница между `ResourceQuota` и `LimitRange`?
5. Как pressure на ноде приводит к eviction Pod?
6. Почему на кластерах с малой RAM quotas и limits обязательны?

## Команды для прохождения
Команды ниже запускайте из директории текущего модуля.

```bash
# 1) Labels и nodeSelector
kubectl label node <node-name> disktype=ssd --overwrite
kubectl -n lab apply -f manifests/selectors/deploy.yaml
kubectl -n lab get pod -l app=select-by-label -o wide

# 2) Taints/tolerations
kubectl taint nodes <node-name> dedicated=lab:NoSchedule --overwrite
kubectl -n lab apply -f manifests/taints/deploy.yaml
kubectl -n lab get pod -l app=taint-toleration-demo -o wide

# 3) Affinity
kubectl -n lab apply -f manifests/affinity/deploy.yaml
kubectl -n lab describe pod -l app=affinity-demo

# 4) Quotas/Limits
kubectl apply -f ../../common/quotas/lab-resourcequota.yaml
kubectl apply -f ../../common/quotas/lab-limitrange.yaml
kubectl -n lab get resourcequota,limitrange
```

## Порядок выполнения
1. Промаркировать ноды и проверить nodeSelector placement.
2. Ввести taint и подтвердить влияние на scheduling.
3. Добавить toleration и убедиться, что Pod планируется.
4. Проверить affinity на реальном Pod.
5. Применить quota/limitrange и валидировать ограничения.

## Практика
- labels/selectors и nodeSelector.
- taints/tolerations.
- affinity/anti-affinity.
- ResourceQuota + LimitRange.


