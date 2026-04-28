---
title: CLAUDE.md — манифест для LLM-агентов
status: stable
audience: [llm, ops]
last_verified: 2026-04-29
---

# Aegis Capstone — гид для агентов

Этот файл загружается LLM-агентами автоматически. Содержит **только то, что нельзя вывести из кода**: канонические имена, правила работы, источники правды.

## Что за проект

Учебный capstone-проект "Aegis Pay" — Zero-Trust распределённая инфраструктура (Azure, 5 VM в 3 регионах) как фундамент под будущий Kubernetes. Базы данных намеренно остаются на VM (не в K8s) — см. [ADR-0001](docs/adr/0001-databases-on-vm-not-k8s.md).

**Стек:** Terraform (`terraform/`) + Ansible (`ansible/`) + WireGuard mesh + observability stack.

Полная архитектура: [ARCHITECTURE.md](ARCHITECTURE.md). План приложения: [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md).

## Канонические имена (не выдумывай свои)

**Узлы (5):** `az-app`, `az-db`, `az-kafka`, `az-etcd`, `az-storage`.

**Tier'ы (5):**
- `ingress-tier` — `az-app` (Nginx, public IP).
- `stateful-tier` — `az-db` (PG/Mongo/Redis).
- `messaging-tier` — `az-kafka`.
- `coordination-tier` — `az-etcd`.
- `storage-tier` — `az-storage` (RAID5, бэкапы).

**Группы Ansible:** `app_nodes`, `db_nodes`, `kafka_nodes`, `etcd_nodes`, `storage_nodes`, `monitor_nodes`, `azure_nodes`, `private_nodes`, `stateful` (мета).

**Регионы:** `r1` = australiaeast, `r2` = australiasoutheast, `r3` = southeastasia.

**WireGuard overlay:** `10.100.0.0/24`, узлы получают IP по индексу в `groups['azure_nodes']` начиная с `.10`.

## Source of Truth (где живёт правда)

| Факт | Источник правды |
|---|---|
| IP-адреса узлов | `terraform output` (после `apply`) → синхронизируется в `ansible/inventory/hosts.ini` |
| Порты сервисов | [docs/ports.md](docs/ports.md) |
| Топология сети, peering | [docs/topology.md](docs/topology.md) и `terraform/azure.tf` |
| Диски и mount-points | `ansible/inventory/host_vars/<host>.yml` (генерится Terraform'ом) |
| Версии provider'ов | `terraform/versions.tf` |
| Архитектурные решения | `docs/adr/` |
| Термины и определения | [docs/glossary.md](docs/glossary.md) |

**Никогда не дублируй эти факты в других местах.** Ссылайся.

## Что НЕ редактировать руками

- `ansible/inventory/host_vars/*.yml` — генерится `terraform/inventory.tf` через `local_file`. Правки исчезнут при следующем `terraform apply`.
- `ansible/inventory/hosts.ini` — генерится тем же способом, **но** сейчас часто правится руками. Перед правкой проверь, что изменения попадут в `inventory.tf` (иначе TF их затрёт).
- `terraform/.terraform/`, `*.tfstate*`, `terraform/.generated/` — служебные/сгенерированные.
- `terraform/${path.module}/`, `terraform/${var.ansible_host_vars_dir}/` — мусор от старого бага, удалить можно (см. [ADR-0005](docs/adr/0005-remove-generate-tf-py.md)).

## Команды воспроизведения

```bash
# Раскатать инфру (создаёт 5 VM, диски, NSG, peering, host_vars/, ssh_config)
cd terraform && terraform apply

# Настроить узлы (storage → kernel → mesh → security → runtime → stateful → app → observability)
cd ansible && ansible-playbook -i inventory/hosts.ini site.yml

# Прогнать sanity-проверку без изменений
ansible-playbook -i inventory/hosts.ini site.yml --check --diff
```

## Что считается "done" для задачи в этом репо

- `terraform plan` чистый (no changes) после `apply`.
- `ansible-playbook --check` без ошибок.
- Все правки в `*.tf` сопровождаются `terraform fmt` и `terraform validate`.
- Если меняется архитектурное решение — добавляется ADR в `docs/adr/`.
- Если меняется порт, узел, tier — обновляется соответствующий SSOT-файл.

## Соглашения

- **Документация — на русском, технические термины — на английском** (Terraform, Ansible, ingress, peering).
- **Inline-комментарии** объясняют **WHY**, не **WHAT**. Под каждым нетривиальным `resource` / задачей — одна строка с обоснованием или ссылкой на ADR.
- **Diagrams as code (Mermaid)**, не PNG.
- **Frontmatter обязателен** в каждом значимом `.md` (см. [docs/RULES.md](docs/RULES.md)).

## Подводные камни

- **R2↔R3 peering отсутствует** в `azure.tf`. Из-за этого `kafka`/`etcd` (r2) не видят `storage` (r3) на L3. WireGuard mesh от этого ломается. Фикс — добавить пары `p23`/`p32`, либо переехать на hub-and-spoke.
- **`provision/azure_*.sh`** — устаревшие bash-скрипты эпохи "до-Terraform". Не использовать. Можно удалить.
- **`generate_tf.py`** удалён (см. [ADR-0005](docs/adr/0005-remove-generate-tf-py.md)). Если видишь его — что-то пошло не так.
