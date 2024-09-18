# Инструкция кластер k8s через kubeadm

## 1 Controle plain 1 Worker (yandex.cloud debian12)

### Controle plain

1. Обновляем список пакетов и устанавливаем необходимые зависимости

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg gnupg lsb-release
```

2. Создаем директорию для хранения ключей APT

```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
```

3. Загружаем ключ для Kubernetes репозитория

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

4. Добавляем Kubernetes репозиторий в систему

```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

5. Устанавливаем необходимые компоненты Kubernetes: kubelet, kubeadm и kubectl, а также фиксируем их версии

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

6. Включаем и запускаем сервис kubelet

```bash
sudo systemctl enable --now kubelet
```

7. Загружаем ключ для Docker репозитория

```bash
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

8. Добавляем Docker репозиторий в систему для установки containerd

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

9. Устанавливаем containerd — контейнерный рантайм, который будет использоваться для Kubernetes

```bash
sudo apt-get update
sudo apt-get install -y containerd.io
```

10. Создаем конфигурацию containerd и генерируем её по умолчанию

```bash
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

11. Открываем конфигурацию containerd для редактирования

```
sudo vi /etc/containerd/config.toml
```

12. Настраиваем использование systemd в качестве драйвера cgroups для containerd

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

13. Перезапускаем сервис containerd после внесения изменений

```bash
sudo systemctl restart containerd
```

14. Проверяем статус containerd, чтобы убедиться, что он работает

```bash
sudo systemctl status containerd
```

15. Проверяем текущее состояние маршрутизации IPv4 (ip_forward), которое нужно для работы Kubernetes

```bash
cat /proc/sys/net/ipv4/ip_forward
```

Если вывод — 0, это означает, что маршрутизация не включена.

Чтобы временно включить пересылку IPv4, выполните следующую команду:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```
Чтобы сделать это изменение постоянным (чтобы оно сохранялось после перезагрузки), добавьте или измените строку в файле /etc/sysctl.conf:

```bash
sudo vi /etc/sysctl.conf
```

Найдите или добавьте строку:

```bash
net.ipv4.ip_forward=1
```
Примените изменения:

```bash
sudo sysctl -p
```

16. Создаем конфигурационный файл для инициализации кластера через kubeadm

```bash
vi kubeadm-config.yaml
```

```
# kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta4
kubernetesVersion: v1.31.0
apiServer:
  certSANs:
  - "10.96.0.1" # Внутренний сервисный IP-адрес
  - "<...>" # Ваш внутренний IP-адрес
  - "<...>"  # Ваш внешний IP-адрес
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
```

17. Инициализируем кластер Kubernetes с помощью kubeadm и созданной конфигурации

```bash
sudo kubeadm init --config kubeadm-config.yaml
```

сохранить вывод комнады типа: 

```
kubeadm join 10.130.0.10:6443 --token bjm5jo.nak9kc6lsljurn1a \
        --discovery-token-ca-cert-hash sha256:fc19c923473ef55a006f8ff3767ccf011d504cebb49b06874fafe54552e442e4
```

18. Настраиваем доступ к кластеру для текущего пользователя, создавая конфигурацию kubectl

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) /etc/kubernetes/admin.conf
export KUBECONFIG=/etc/kubernetes/admin.conf
```

19. Устанавливаем сетевой плагин Calico для поддержки сетей в кластере

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

20. Проверяем состояние узлов кластера

```bash
kubectl get nodes
```

21. Выводим список доступных токенов для присоединения воркер-узлов

```bash
kubeadm token list
```

### Worker

22. Обновляем список пакетов и устанавливаем зависимости на воркер-узле

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
```

23. Создаем директорию для хранения ключей APT

```bash
sudo mkdir -p /etc/apt/keyrings
```

24. Загружаем ключ для Docker репозитория

```bash
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

25. Добавляем Kubernetes репозиторий на воркер-узле

```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

26. Добавляем Docker репозиторий на воркер-узле

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

27. Устанавливаем kubelet, kubeadm и kubectl на воркер-узле

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

28. Устанавливаем containerd на воркер-узле

```bash
sudo apt-get update
sudo apt-get install -y containerd.io
```

29. Создаем конфигурацию containerd и генерируем её по умолчанию

```bash
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

30. Открываем конфигурацию containerd для редактирования и настраиваем использование systemd

```bash
sudo vi /etc/containerd/config.toml
```

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

31. 

```bash
sudo systemctl restart containerd
```

32. Перезапускаем containerd на воркер-узле

```bash
sudo systemctl status containerd
```

33. Проверяем текущее значение ip_forward и включаем пересылку пакетов, если требуется

```bash
cat /proc/sys/net/ipv4/ip_forward
```

Если вывод — 0, это означает, что маршрутизация не включена.

Чтобы временно включить пересылку IPv4, выполните следующую команду:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```
Чтобы сделать это изменение постоянным (чтобы оно сохранялось после перезагрузки), добавьте или измените строку в файле /etc/sysctl.conf:

```bash
sudo vi /etc/sysctl.conf
```

Найдите или добавьте строку:

```bash
net.ipv4.ip_forward=1
```
Примените изменения:

```bash
sudo sysctl -p
```

34. Присоединяем воркер-узел к кластеру с использованием команды из пункта 17

```bash
sudo kubeadm join <внутренний-ip-master>:6443 --token <ваш токен см. пункт 17> \
    --discovery-token-ca-cert-hash sha256:<ваш hash см. пункт 17>
```
