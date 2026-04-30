---
title: Runbook — раскатка инфраструктуры с нуля
status: stable
audience: [ops, llm]
last_verified: 2026-04-30
related:
  - ../../packer/
  - ../../terraform/
  - ../../ansible/
  - deploy-services.md
---

# Runbook: Раскатка с нуля (Packer → Terraform → Ansible)

> Полный путь от пустого Azure-аккаунта до 5 настроенных VM с Zero-Trust mesh. Дальнейший шаг — деплой микросервисов: см. [`deploy-services.md`](deploy-services.md).

## Архитектурный обзор пайплайна

```
1. az login                            (auth)
2. Создать RG + Compute Gallery        (одноразово, цели для Packer)
3. packer build                        (~10 минут → image в gallery)
4. terraform apply                     (~7 минут → 5 VM из этого image)
5. ansible-playbook                    (~15 минут → конфиг, mesh, БД)
6. deploy-services.md                  (~5 минут → сервисы на az-app)
```

Без Packer-image шаг 4 **гарантированно упадёт** — `terraform/azure.tf` использует `data "azurerm_shared_image_version" "latest"` (Compute Gallery), не marketplace-image.

---

## Предусловия

- [ ] Установлено: `terraform >= 1.5`, `packer >= 1.10`, `ansible >= 2.16` (например в `/root/.venv/bin/ansible-playbook`), `az` CLI, `ssh`, `wg` (для проверки).
- [ ] Активная Azure подписка с quota на `Standard_D2s_v5` ≥ 12 vCPU суммарно по 3 регионам Asia-Pacific.
- [ ] SSH-ключ `~/.ssh/id_ed25519` (создать: `ssh-keygen -t ed25519`).
- [ ] Свой публичный IP: `curl -s ifconfig.me`.
- [ ] `az login` выполнен; `az account show` показывает нужную subscription.
- [ ] Установлена Ansible-коллекция: `ansible-galaxy collection install community.general`.

---

## Шаг 1. Подготовить `terraform.tfvars`

```bash
cd /root/lern/aegis-capstone/terraform
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
```

Заполнить:
```hcl
azure_subscription_id = "<subscription-id>"
operator_ip           = "<your-public-ip>/32"
azure_locations       = ["australiaeast", "australiasoutheast", "southeastasia"]
azure_vm_size         = "Standard_D2s_v5"
```

> **Не коммить** `terraform.tfvars` — он в `.gitignore`.

---

## Шаг 2. Создать RG + Compute Gallery + image-definition (одноразово)

Packer **не создаёт** ни RG, ни gallery — они должны существовать до build'а.

> ⚠️ **Подводный камень (грабли #1).** Packer-RG и TF-RG **должны находиться в одном регионе**, либо это должны быть **разные RG**. По умолчанию Packer кладёт image в RG `aegis-v4-az-r1` в `southeastasia`. Если первый элемент `azure_locations` в tfvars — другой регион (`australiaeast`), то `terraform apply` попытается **destroy и recreate** RG `aegis-v4-az-r1` (нельзя поменять location у RG), уничтожив Packer-image.
>
> **Два решения, выбрать одно:**
>
> **A) Использовать `southeastasia` как `r1`** (рекомендую — работает «из коробки»).
> В `terraform.tfvars`:
> ```hcl
> azure_locations = ["southeastasia", "australiasoutheast", "australiaeast"]
> ```
>
> **B) Разделить Packer-RG и TF-RG.**
> Изменить `packer/ubuntu-base.pkr.hcl`:
> ```hcl
> shared_image_gallery_destination {
>   resource_group = "aegis-images"   # отдельный, не aegis-v4-az-r1
>   ...
> }
> managed_image_resource_group_name = "aegis-images"
> ```
> и в `terraform/azure.tf` (data source):
> ```hcl
> data "azurerm_shared_image_version" "latest" {
>   resource_group_name = "aegis-images"
>   ...
> }
> ```
> Тогда `aegis-v4-az-r1` создастся чисто Terraform'ом в любом регионе, а Packer-артефакты живут отдельно. Чище, но требует правок кода.

```bash
# Вариант A (далее по runbook):
az group create --name aegis-v4-az-r1 --location southeastasia

az sig create \
  --resource-group aegis-v4-az-r1 \
  --gallery-name aegis_gallery

az sig image-definition create \
  --resource-group aegis-v4-az-r1 \
  --gallery-name aegis_gallery \
  --gallery-image-definition aegis-ubuntu-base \
  --publisher aegis --offer ubuntu --sku 22-04 \
  --os-type Linux --hyper-v-generation V2
```

После шага 4 (`terraform apply`) Terraform увидит, что `aegis-v4-az-r1` уже существует, и попросит import:
```bash
terraform import azurerm_resource_group.r1 \
  /subscriptions/<sub-id>/resourceGroups/aegis-v4-az-r1
```
После import `terraform plan` чистый.

---

## Шаг 3. Packer build — собрать base image

```bash
cd /root/lern/aegis-capstone/packer
export ARM_SUBSCRIPTION_ID=<your-subscription-id>

packer init .          # одноразово: скачать azure plugin
packer validate .      # быстрая проверка синтаксиса
packer build ubuntu-base.pkr.hcl
```

Время: 8–12 минут. В процессе:
1. Создаётся temp VM в `southeastasia` из Canonical Ubuntu 22.04 LTS Gen2.
2. На неё ставятся: `lvm2`, `xfsprogs`, `mdadm`, `wireguard`, `auditd`, `ufw`, `nginx`, Docker (engine + compose plugin), containerd, `node_exporter`.
3. VM деallocates, snapshot уезжает в `aegis_gallery/aegis-ubuntu-base/1.0.<timestamp>` с replication в три региона.

**Аутентификация:**
- По умолчанию используется `az login`-идентичность (через `use_azure_cli_auth = true` в `ubuntu-base.pkr.hcl`).
- Если нужен service principal — установи `ARM_CLIENT_ID`/`ARM_CLIENT_SECRET`/`ARM_TENANT_ID` (он перекроет CLI-auth).

После успеха — никакой ручной правки `terraform.tfvars` не требуется: `azure.tf` пайпит **последнюю версию** image из gallery через data source.

---

## Шаг 4. `terraform apply`

```bash
cd /root/lern/aegis-capstone/terraform
terraform init
terraform validate
terraform plan        # должно показать ~50 ресурсов "to add"
terraform apply       # подтвердить → 5–7 минут
```

После успеха:
- 3 RG (`aegis-v4-az-r{1,2,3}`), 3 VNet, 6 peerings (попарно r1↔r2, r1↔r3, r2↔r3).
- 5 VM (`az-app`/`az-db` в r1, `az-kafka`/`az-etcd` в r2, `az-storage` в r3) — все из Packer-образа.
- Managed disks и attachments по `local.az_vms`.
- Сгенерируются: `terraform/.generated/ssh_config`, `ansible/inventory/hosts.ini`, `ansible/inventory/host_vars/*.yml`.

**Если `apply` падает на `data.azurerm_shared_image_version.latest`** — Packer-образ ещё не залит/реплицировался; вернись на шаг 3.

---

## Шаг 5. SSH-связность

```bash
export SSH_CONFIG=/root/lern/aegis-capstone/terraform/.generated/ssh_config

# Public узел
ssh -F $SSH_CONFIG az-app whoami        # → ansible_user

# Private узлы (через ProxyJump az-app)
ssh -F $SSH_CONFIG az-db whoami
ssh -F $SSH_CONFIG az-kafka whoami
ssh -F $SSH_CONFIG az-etcd whoami
ssh -F $SSH_CONFIG az-storage whoami
```

Если что-то не отвечает — **не запускать Ansible**, разбираться с NSG / ProxyCommand.

---

## Шаг 6. `ansible-playbook`

```bash
cd /root/lern/aegis-capstone/ansible

# Sanity: ansible видит все 5 узлов
/root/.venv/bin/ansible -i inventory/hosts.ini all -m ping

# Сухой прогон
/root/.venv/bin/ansible-playbook -i inventory/hosts.ini site.yml --check --diff

# Реальный прогон (~15 минут)
/root/.venv/bin/ansible-playbook -i inventory/hosts.ini site.yml
```

Порядок плеев `site.yml`:
1. `01-storage` — диски/LVM/RAID/mount (LUN-based discovery).
2. `02-kernel` — sysctl, THP, модули.
3. `05-overlay-network` — WireGuard mesh (full mesh из всех в `azure_nodes`).
4. `03-security` — UFW (с правилом для WG/51820 udp), SSH hardening, auditd.
5. `04-runtime` — Docker engine + compose plugin (только на `runtime_hosts` = `app_nodes`).
6. `06-stateful-tier` — PG / Mongo / Redis / Kafka / etcd.
7. `05-app-sandbox` — sandbox-сервис.
8. `07-observability` — VictoriaMetrics, Grafana, node_exporter.

**Критично для WG-mesh:** прогон должен быть в **одном `ansible-playbook`-инвокации** — шаблон `wg0.conf.j2` использует `hostvars[peer].wg_public_key`, который определяется только внутри текущего прогона. Если запускать `--limit az-app` и потом `--limit az-db` — wg-конфиги получатся неполные.

---

## Шаг 7. Проверить mesh

```bash
ansible -i inventory/hosts.ini azure_nodes -b -m shell -a 'wg show wg0 latest-handshakes'
```

У каждого узла должно быть **4 peer'а** с handshake-таймстампом в пределах ~30 сек. Если у кого-то 0 peer'ов — wg-конфиг не отрендерил `[Peer]`-блоки (см. предупреждение выше).

```bash
# Cross-overlay ping
ansible -i inventory/hosts.ini azure_nodes -b -m shell -a 'ping -c 2 10.100.0.10'
```

---

## Шаг 8. Деплой микросервисов

См. [`deploy-services.md`](deploy-services.md).

Public IP `az-app` берётся динамически:
```bash
APP_IP=$(terraform -chdir=/root/lern/aegis-capstone/terraform output -raw app_public_ip 2>/dev/null \
         || awk '/^az-app/{for(i=1;i<=NF;i++)if($i~/ansible_host/)split($i,a,"=") ;print a[2]}' \
            /root/lern/aegis-capstone/ansible/inventory/hosts.ini)
echo "az-app: $APP_IP"
```

---

## Полная очистка (teardown)

> ⚠️ Деструктивно. Сносит **всё**: VMs, managed disks с данными БД, RG/VNet/NSG, **а также Packer-артефакты** (gallery + image-version + managed image). Делать только когда работа завершена.

### Шаг 1. Остановить compose на az-app (опционально)

`terraform destroy` всё равно снесёт VM, но если хочется чистого down первым:
```bash
APP_IP=$(awk '/^az-app/{for(i=1;i<=NF;i++) if($i ~ /^ansible_host=/) print substr($i,14)}' \
          /root/lern/aegis-capstone/ansible/inventory/hosts.ini)
ssh -i ~/.ssh/id_ed25519 ansible_user@$APP_IP \
  'cd /opt/aegis-app && docker compose down --volumes' 2>&1 | tail
```
Снимет 8 контейнеров + named volumes (`pgdata`, `redisdata`, `mongodata`).

### Шаг 2. `terraform destroy` — основная масса

```bash
cd /root/lern/aegis-capstone/terraform
terraform destroy -auto-approve
```

Время: 5–10 минут. Уничтожит всё, что в `terraform.tfstate`:
- 5 VM (`az-app/db/kafka/etcd/storage`)
- managed disks + attachments (включая RAID 5 диски storage)
- 3 NSG, 3 NIC, public IP `pip-app`
- 3 VNet, 3 subnet, 6 peering объектов
- 3 RG (`aegis-v4-az-r1/r2/r3`) — **частично**

> ⚠️ **Важно:** `terraform destroy` может зависнуть/упасть на удалении `aegis-v4-az-r1`, потому что там лежат **не управляемые TF ресурсы** — Compute Gallery (`aegis_gallery`), image-definition (`aegis-ubuntu-base`), image-version (`1.0.<timestamp>`), managed image (`aegis-base-<timestamp>`). Это нормально — переходи к шагу 3.

### Шаг 3. Удалить Packer-артефакты + дочистить RG

После `terraform destroy` (даже если упал на RG r1) — удалить RG целиком через `az`:

```bash
SUB=7c020354-cb51-4f0a-8265-59d8fbbdc041

# Удалить все 3 RG (--no-wait → возвращается мгновенно, удаление в фоне)
az group delete --name aegis-v4-az-r1 --yes --no-wait
az group delete --name aegis-v4-az-r2 --yes --no-wait
az group delete --name aegis-v4-az-r3 --yes --no-wait

# Подождать удаления (опционально, иначе billing продолжится фоново)
for rg in aegis-v4-az-r1 aegis-v4-az-r2 aegis-v4-az-r3; do
  echo -n "waiting for $rg... "
  until ! az group show -n $rg --query name -o tsv 2>/dev/null; do sleep 15; done
  echo "GONE"
done

# Финальная проверка
az group list --query "[?starts_with(name, 'aegis')].{name:name,location:location}" -o table
# Должно быть пусто.
```

### Шаг 4. Локальная очистка (опционально)

Эти файлы пересоздаются при следующем `apply`, но если хочется чистого репо:

```bash
cd /root/lern/aegis-capstone

# Локальный Terraform state и артефакты
rm -f terraform/terraform.tfstate terraform/terraform.tfstate.backup
rm -rf terraform/.generated/ terraform/.terraform/

# Сгенерированный inventory (Terraform пересоздаст при следующем apply)
rm -f ansible/inventory/hosts.ini ansible/inventory/host_vars/*.yml

# Логи прогонов
rm -f /tmp/tfapply*.log /tmp/tfdestroy.log /tmp/ansible.log /tmp/packer.log
```

> ⚠️ **`terraform.tfstate`** удалять нужно только если уверен, что в Azure точно ничего не осталось — иначе следующий `apply` будет считать, что инфры нет, и создаст дубль.

### Что НЕ удаляется

- `terraform.tfvars` (там твой `subscription_id` и `operator_ip` — пригодятся для следующего раза).
- `~/.ssh/id_ed25519` — ключ оператора, не трогаем.
- Локальные образы Packer plugins (`terraform/.terraform/providers/`) — переиспользуются.

### Проверка биллинга

После полного teardown в Azure-портале (Cost Management) убедиться, что:
- Нет ресурсов с тегом `project=aegis`.
- `Standard_D2s_v5` instances → 0.
- Premium_LRS managed disks → 0.
- Public IPs → 0.

---

## Troubleshooting (грабли, на которых уже стояли)

### `terraform apply` падает на `data.azurerm_shared_image_version.latest`
Packer-образ не залит, gallery пуст или image-definition отличается от того, на что смотрит `azure.tf`. Проверить:
```bash
az sig image-version list \
  --resource-group aegis-v4-az-r1 \
  --gallery-name aegis_gallery \
  --gallery-image-definition aegis-ubuntu-base
```
Список не пустой? Если пустой — повторить шаг 3.

### `wg show wg0` показывает 0 peer'ов
Шаблон `wg0.conf.j2` не отрендерил peer-блоки. Причина почти всегда: `ansible-playbook` запустили с `--limit` или часть узлов оффлайн. Решение: один прогон без `--limit` на всех `azure_nodes`.

### `pg_isready` / `redis-cli ping` отказ с других узлов
БД слушают на `127.0.0.1` после роли `06-stateful-tier`. Это известный gap (см. [ADR-0007](../adr/0007-local-stateful-in-compose.md) — Phase 3 сменит bind на overlay-IP). Сейчас сервисы коннектятся к локально-запущенному PG/Redis в compose на az-app, не к узлу az-db.

### Packer build падает с `AuthorizationFailed`
1. Проверь `az account show` — нужная подписка?
2. Если используется `use_azure_cli_auth` — у пользователя должна быть роль `Contributor` на subscription.
3. Альтернатива: создать service principal:
   ```bash
   az ad sp create-for-rbac --name aegis-packer --role Contributor \
     --scopes /subscriptions/<sub-id>
   ```
   и экспортировать `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`.

### `terraform.tfstate` потерян
Если был сделан `git clean` или удаление файла — backup лежит в `terraform.tfstate.backup`. Восстанавливать только если уверен, что в Azure по-прежнему живут те же ресурсы (`az resource list` подтверждает). Иначе проще полный `apply` с нуля.

### Packer build: `ResourceNotFound` на финальном Publish to Gallery
Известный glitch Azure ARM eventual consistency. Despite Packer CLI показывает 404 ("Resource ... aegis-ubuntu-base/versions/X not found"), **image обычно реально создан**. Проверить:
```bash
az sig image-version list \
  --resource-group aegis-v4-az-r1 \
  --gallery-name aegis_gallery \
  --gallery-image-definition aegis-ubuntu-base
```
Если версия в списке (`Succeeded`) — Packer-CLI exit-code 1 можно игнорировать, идти дальше. Repeat build = ещё 13 минут впустую.

### `terraform apply` хочет destroy RG `aegis-v4-az-r1`
Plan показывает `-/+ destroy and then create replacement` для resource group r1 с `forces replacement` на `location`. Причина: Packer положил RG в `southeastasia`, а первый элемент `azure_locations` в `terraform.tfvars` — другой регион. **Не запускать `apply`** — это уничтожит Packer-image. Решение — см. шаг 2 (либо `azure_locations[0] = "southeastasia"`, либо разделить RG для Packer и TF).

### `terraform apply` падает на race condition в r3 (404 на vnet/subnet/disk)
При пересоздании RG r3 ресурсы внутри иногда упираются в Azure ARM eventual consistency: peering `p31`, `nic-storage`, `disk-storage-raid2` падают с 404 на vnet/subnet, который "только что создался". **Просто повторить `terraform apply` 1-2 раза** — TF подхватит. Если ресурс «already exists» — `terraform import`:
```bash
terraform import azurerm_managed_disk.disks[\"storage-raid0\"] /subscriptions/<sub>/resourceGroups/aegis-v4-az-r3/providers/Microsoft.Compute/disks/disk-storage-raid0
terraform import azurerm_virtual_network_peering.p31 /subscriptions/<sub>/resourceGroups/aegis-v4-az-r3/providers/Microsoft.Network/virtualNetworks/vnet-r3/virtualNetworkPeerings/p31
```

### Docker compose: `ERROR: Failed building wheel for aiokafka` на alpine
`python:3.12-alpine` не имеет `gcc`, а у `aiokafka` нет prebuilt wheel'а для musl libc. Решение — `python:3.12-slim` (debian-based) во всех `app/*/Dockerfile`. Уже исправлено.

### Healthcheck в compose говорит `unhealthy` на slim base
`python:3.12-slim` не имеет ни `wget`, ни `curl`. Healthcheck использует Python urllib:
```yaml
test: ["CMD-SHELL", "python3 -c \"import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1/health', timeout=3).status==200 else 1)\""]
```

### Старые артефакты пайплайна
- `provision/azure_*.sh` — устаревшие bash-скрипты до-Terraform-эпохи. Не использовать.
- `terraform/generate_tf.py` — удалён по [ADR-0005](../adr/0005-remove-generate-tf-py.md). Если появился снова — что-то пошло не так.
- Папки с буквальными именами `${path.module}/`, `${var.ansible_host_vars_dir}/` в `terraform/` — мусор от старого бага, удалить.
