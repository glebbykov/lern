# 04-networking

Цель: разобраться с маршрутизацией внутри кластера и на входе.

## Теория (расширенная)
- Pod получает IP через CNI; модель Kubernetes предполагает прямую Pod-to-Pod связность.
- `Service` дает виртуальный IP и стабильное имя, а `kube-proxy` на нодах программирует правила маршрутизации.
- Реальные backend-адреса хранятся в `Endpoints/EndpointSlice`; не-Ready Pod туда не попадает.
- CoreDNS резолвит `*.svc.cluster.local`, используя search domains namespace.
- `NodePort` публикует сервис на IP ноды и фиксированном порту.
- `Ingress` маршрутизирует HTTP(S) по host/path к сервисам.
- `NetworkPolicy` задает allow-list модель для ingress/egress.

## Теоретические вопросы
1. Как Pod получает IP и какую роль в этом играет CNI?
2. Что делает `kube-proxy` для Service в режимах `iptables/ipvs`?
3. Чем отличаются `ClusterIP`, `NodePort`, `LoadBalancer`, `ExternalName`?
4. В чем разница между `Service` и `Endpoints/EndpointSlice`?
5. Как CoreDNS резолвит имя `service.namespace.svc.cluster.local`?
6. Почему default deny в `NetworkPolicy` считается базовым безопасным подходом?

## Команды для прохождения
Команды ниже запускайте из директории текущего модуля.

```bash
# 1) Базовый сервис и DNS
kubectl -n lab apply -f manifests/services/
kubectl -n lab get deploy,svc,endpoints -o wide
kubectl -n lab run dnscheck --image=busybox:1.36 --restart=Never -- nslookup net-demo.lab.svc.cluster.local
kubectl -n lab logs dnscheck

# 2) NodePort
kubectl -n lab apply -f manifests/nodeport/svc-nodeport.yaml
kubectl -n lab get svc net-demo-nodeport -o wide

# 3) Ingress
kubectl -n lab apply -f manifests/ingress/ingress.yaml
kubectl -n lab get ingress net-demo

# 4) NetworkPolicy
kubectl -n lab apply -f manifests/netpol/default-deny.yaml
kubectl -n lab apply -f manifests/netpol/allow-dns.yaml
kubectl -n lab apply -f manifests/netpol/allow-app.yaml
kubectl -n lab get netpol
```

## Порядок выполнения
1. Проверить Pod-to-Service связь и DNS.
2. Поднять NodePort и убедиться в доступе снаружи.
3. Настроить Ingress для host/path.
4. Включить default deny и поэтапно добавить нужные allow.
5. При проблемах диагностировать цепочку `Ingress -> Service -> Endpoints -> Pod -> logs`.

## Темы
- Pod-to-Service и DNS.
- Service types: ClusterIP и NodePort.
- Ingress и цепочка `Ingress -> Service -> Endpoints -> Pod`.
- NetworkPolicy: default deny + точечные allow.


