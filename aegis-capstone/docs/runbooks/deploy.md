---
title: Runbook — раскатка инфраструктуры с нуля
status: stable
audience: [ops, llm]
last_verified: 2026-04-29
related:
  - terraform/
  - ansible/
---

# Runbook: Раскатка с нуля

> Пошаговая процедура от пустого Azure-аккаунта до полностью настроенных 5 VM с Zero-Trust mesh.

## Предусловия

- [ ] Локально установлены: `terraform >= 1.5`, `ansible >= 2.16`, `az` CLI, `ssh`, `wg` (для проверки).
- [ ] Активная Azure подписка с достаточной quota на `Standard_D2s_v5` в трёх регионах.
- [ ] SSH ключ `~/.ssh/id_ed25519` (можно сгенерить: `ssh-keygen -t ed25519`).
- [ ] Свой публичный IP известен: `curl ifconfig.me`.
- [ ] `az login` выполнен.
- [ ] Установлена коллекция Ansible: `ansible-galaxy collection install community.general`.

## Шаг 1. Подготовить `terraform.tfvars`

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
```

Заполнить:
```hcl
azure_subscription_id = "<your-subscription-id>"
operator_ip           = "<your-public-ip>/32"
```

> **Не коммить** `terraform.tfvars` — он в `.gitignore`.

## Шаг 2. `terraform apply`

```bash
terraform init       # одноразово, скачает provider'ов
terraform validate   # синтаксис ок?
terraform plan       # просмотреть, что создастся
terraform apply      # подтвердить → 5–7 минут
```

После `apply`:
- Создаётся 5 VM, 3 RG, 3 VNet, peering, NSG, managed disks.
- Сгенерируется `terraform/.generated/ssh_config` (для удобного SSH).
- Сгенерируются `ansible/inventory/hosts.ini` и `ansible/inventory/host_vars/*.yml`.

## Шаг 3. Проверить SSH-связность

```bash
# Подгрузить сгенерённый ssh_config
export SSH_CONFIG=$PWD/.generated/ssh_config

# Public узел
ssh -F $SSH_CONFIG az-app whoami
# → ansible_user

# Private узлы (через ProxyJump)
ssh -F $SSH_CONFIG az-db whoami
ssh -F $SSH_CONFIG az-kafka whoami
ssh -F $SSH_CONFIG az-etcd whoami
ssh -F $SSH_CONFIG az-storage whoami
```

Если хоть один shell не открывается — стоп, разбираться с NSG/ProxyCommand. Не запускать Ansible.

## Шаг 4. `ansible-playbook` (dry-run)

```bash
cd ../ansible/
ansible -i inventory/hosts.ini azure_nodes -m ping       # все 5 узлов отвечают?
ansible-playbook -i inventory/hosts.ini site.yml --check  # сухой прогон
```

## Шаг 5. Полный прогон

```bash
ansible-playbook -i inventory/hosts.ini site.yml
```

Порядок плеев (см. `site.yml`):
1. `01-storage` — диски/LVM/mount.
2. `02-kernel` — sysctl/THP/модули.
3. `05-overlay-network` — WireGuard mesh.
4. `03-security` — UFW + sshd hardening + auditd.
5. `04-runtime` — containerd (только app).
6. `06-stateful-tier` — БД и Kafka и etcd.
7. `05-app-sandbox` — sandbox-сервис на app.
8. `07-observability` — VictoriaMetrics, Grafana, node_exporter.

> Текущий `site.yml` неполный (запускает только `05-overlay-network`) — это блокер. План доводки в [PROJECT_PLAN.md](../PROJECT_PLAN.md) Phase 0.

## Шаг 6. Проверить mesh

```bash
# WG-handshakes
ansible -i inventory/hosts.ini azure_nodes -b -m shell -a 'wg show wg0 latest-handshakes'
# Все должны иметь handshake в пределах 30 секунд.

# Ping по overlay
ansible -i inventory/hosts.ini azure_nodes -b -m shell -a 'ping -c 2 10.100.0.10'
# С каждого узла должны видеть az-app.
```

## Шаг 7. Открыть Grafana

```bash
ssh -F .generated/ssh_config -L 3000:localhost:3000 az-app
# в браузере: http://localhost:3000
```

## Откат

```bash
cd terraform/
terraform destroy
```

> ⚠️ `destroy` снесёт **все managed disks**. Если в БД были данные — они потеряны (нет `prevent_destroy`).

## Известные проблемы

- **`r2↔r3` peering отсутствует** ([ADR-0006](../adr/0006-r2-r3-peering.md)) → handshake между r2-узлами и `az-storage` не пройдёт.
- **`generate_tf.py`** ([ADR-0005](../adr/0005-remove-generate-tf-py.md)) → если он ещё не удалён, не запускать его.
- **`hosts.ini` мог быть отредактирован руками** — после `terraform apply` правки могут быть затёрты. Сверить с git diff.
