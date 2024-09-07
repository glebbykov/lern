# Инструкция кластер k8s через kubeadm

## 1 Контрлплейн 1 воркер (yac debian12)

### Controle plain

1. 

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg gnupg lsb-release
```

2.

```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
```

3.

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

4.

```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

5.

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

6. 

```bash
sudo systemctl enable --now kubelet
```

7. 

```bash
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

8.

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

9. 

```bash
sudo apt-get update
sudo apt-get install -y containerd.io
```

10.

```bash
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

11.

```
sudo vi /etc/containerd/config.toml
```

12.

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

13.

```bash
sudo systemctl restart containerd
```

14.

```bash
sudo systemctl status containerd
```

15. Проверьте текущее значение ip_forward:

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
Копировать код
sudo sysctl -p

16.

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

17.

```bash
sudo kubeadm init --config kubeadm-config.yaml
```
сохранить вывод комнады типа 

```
kubeadm join 10.130.0.10:6443 --token bjm5jo.nak9kc6lsljurn1a \
        --discovery-token-ca-cert-hash sha256:fc19c923473ef55a006f8ff3767ccf011d504cebb49b06874fafe54552e442e4
```

18.

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf
```

19.

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

20.

```bash
kubectl get nodes
```

21.

```bash
kubeadm token list
```

### Worker

21.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
```

22.

```bash
sudo mkdir -p /etc/apt/keyrings
```

23.

```bash
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

24.

```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

25.

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

26.

```bash
sudo kubeadm join 10.130.0.10:6443 --token <ваш токен см. пункт 17> \
    --discovery-token-ca-cert-hash sha256:<ваш hash см. пункт 17>
```
