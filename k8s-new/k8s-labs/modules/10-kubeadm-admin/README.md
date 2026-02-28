# 10-kubeadm-admin

Цель: базовое администрирование kubeadm-кластера без простоя сервисов.

## Теория (расширенная)
- kubeadm разворачивает и обслуживает control-plane, включая сертификаты и bootstrap конфиги.
- В kubeadm control-plane обычно работает как static pod (`/etc/kubernetes/manifests`).
- `kubelet` поднимает static pods и пишет ключевые логи через systemd/journal.
- `cordon/drain/uncordon` — безопасная последовательность обслуживания ноды.
- etcd хранит состояние кластера; backup/restore — обязательная часть админ-практики.
- Upgrade требует поэтапности и проверки совместимости control-plane/worker версий.

## Теоретические вопросы
1. За какие этапы жизненного цикла кластера отвечает `kubeadm`?
2. Почему control-plane в kubeadm часто работает как static pod?
3. В какой последовательности безопасно выполнять `cordon`, `drain`, `uncordon`?
4. Как проверять и планировать ротацию сертификатов в кластере?
5. Почему backup/restore `etcd` критичен для восстановления кластера?
6. Какой безопасный порядок обновления control-plane и worker нод?

## Команды для прохождения
Команды ниже запускайте из директории текущего модуля.

```bash
# 1) Базовая проверка кластера
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide

# 2) Обслуживание ноды
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
kubectl get nodes
kubectl uncordon <node-name>

# 3) Сертификаты (на control-plane хосте)
sudo kubeadm certs check-expiration

# 4) Где смотреть static pod и kubelet
sudo ls -la /etc/kubernetes/manifests
sudo journalctl -u kubelet -n 200 --no-pager
```

## Порядок выполнения
1. Снять baseline состояния нод и системных pod.
2. Выполнить `cordon -> drain` для выбранной ноды.
3. Проверить, что workload безопасно перераспределился.
4. Выполнить `uncordon` и убедиться в восстановлении планирования.
5. Проверить сертификаты и базовые точки диагностики control-plane.

## Практика
- `cordon/drain/uncordon`.
- Где лежат static pod control-plane.
- kubeconfig/certs и базовая ротация.

## Критерий готовности
Умеете безопасно вывести ноду из обслуживания и вернуть обратно.


