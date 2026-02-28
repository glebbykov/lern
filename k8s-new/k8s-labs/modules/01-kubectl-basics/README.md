# 01-kubectl-basics

Цель: быстро ориентироваться в кластере и уверенно пользоваться `kubectl`.

## Теория
- Kubernetes API-centric: любой вызов `kubectl` идет в `kube-apiserver`.
- Control-plane: `apiserver` принимает запросы, `etcd` хранит состояние, `scheduler` планирует Pod, `controller-manager` синхронизирует фактическое состояние с желаемым.
- Node stack: `kubelet` запускает Pod через container runtime, `kube-proxy` обслуживает Service networking, CNI выдает Pod IP.
- `Namespace` изолирует ресурсы, `Deployment` поддерживает число реплик, `Service` дает стабильный сетевой endpoint.
- Диагностика: `get` отвечает «что есть», `describe` — «почему так», `logs` — «что говорит приложение», `exec` — «что внутри контейнера».

## Теоретические вопросы
1. Почему `kubectl` считается API-клиентом, а не прямым инструментом управления нодами?
2. Какую роль играет `etcd` в модели desired state?
3. В чем различие между `Pod`, `Deployment` и `ReplicaSet`?
4. Зачем нужен `Namespace` и какие проблемы он решает в команде?
5. Чем `kubectl get` концептуально отличается от `kubectl describe`?
6. Почему у `Service` стабильный адрес, даже когда Pod пересоздаются?

## Команды для прохождения
Команды ниже запускайте из директории текущего модуля.

```bash
# 1) Проверка контекста и кластера
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide

# 2) Проверка системных компонентов
kubectl -n kube-system get pods -o wide

# 3) Работа с namespace
kubectl get ns
kubectl create ns lab --dry-run=client -o yaml | kubectl apply -f -

# 4) Деплой приложения
kubectl -n lab apply -f manifests/app/deploy.yaml
kubectl -n lab apply -f manifests/app/svc.yaml
kubectl -n lab get deploy,po,svc -o wide

# 5) Базовая диагностика
kubectl -n lab describe deploy kb-web
kubectl -n lab logs deploy/kb-web --tail=100
kubectl -n lab get endpoints kb-web -o wide

# 6) Проверка DNS из debug pod
kubectl -n lab run dnscheck --image=busybox:1.36 --restart=Never -- nslookup kb-web.lab.svc.cluster.local
kubectl -n lab logs dnscheck
kubectl -n lab delete pod dnscheck --ignore-not-found
```

## Порядок выполнения
1. Проверить контекст и состояние нод.
2. Создать/проверить namespace `lab`.
3. Применить `Deployment` и `Service`.
4. Дождаться `Ready` состояния Pod.
5. Проверить `endpoints` и DNS-резолв сервиса.
6. При сбое пройти цикл `describe -> logs -> exec`.

## Практика
- Инвентаризация кластера (`nodes`, `pods -A`, `events`).
- Деплой `Deployment + Service` в namespace `lab`.
- Диагностика проблем через `describe`, `logs`, `exec`.

## Критерий готовности
За 10 минут поднимаете приложение и локализуете причину `CrashLoopBackOff`.
