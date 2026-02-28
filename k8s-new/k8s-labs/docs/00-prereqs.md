# 00-prereqs

## Цели
- Понимать Linux networking: IP, route, DNS, iptables/nftables, conntrack.
- Понимать контейнеры: image, registry, namespaces, cgroups, overlayfs.
- Уверенно работать с YAML, JSONPath и базовыми командами `kubectl`.

## Минимальный чеклист
```bash
uname -a
ip a
ip r
cat /etc/resolv.conf
sudo iptables -S || true
sudo nft list ruleset || true
sudo conntrack -L | head || true
crictl info || true
ctr -n k8s.io images ls || true
```

## Что объяснить перед стартом
- Как Pod получает IP (CNI).
- Как Pod резолвит `*.svc` (CoreDNS + search domains).
- За что отвечает kube-proxy и как это связано с Service.
