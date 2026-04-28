---
title: Глоссарий проекта
status: stable
audience: [llm, contributors, reviewers]
last_verified: 2026-04-29
---

# Глоссарий

Канонические термины проекта. Если термина нет здесь — добавь, не выдумывай синонимы.

## Узлы и tier'ы

- **`az-app`** — узел ingress-tier'а (Nginx, public IP, observability stack, будущий K8s control-plane).
- **`az-db`** — узел stateful-tier'а (PostgreSQL, MongoDB, Redis на изолированных дисках).
- **`az-kafka`** — узел messaging-tier'а (Kafka в KRaft, 2 диска JBOD).
- **`az-etcd`** — узел coordination-tier'а (etcd, single-node).
- **`az-storage`** — узел storage-tier'а (RAID 5 из 3 дисков, бэкапы).
- **ingress-tier / stateful-tier / messaging-tier / coordination-tier / storage-tier** — пять логических слоёв архитектуры.

## Сеть

- **VNet** — Azure Virtual Network (`vnet-r1/r2/r3`).
- **Subnet** — подсеть внутри VNet (`s1/s2/s3`).
- **Peering** — связь между двумя VNet (`p12`, `p21` и т.д.).
- **Overlay** — WG-сеть `10.100.0.0/24` поверх VNet/peering.
- **Operator IP** — IP оператора, с которого разрешён SSH (`var.operator_ip`).

## Хранилище

- **Managed disk** — Azure-управляемый блочный девайс, attached к VM.
- **LUN** — порядковый номер data-диска при attach (Azure-специфично).
- **VG / LV** — LVM Volume Group / Logical Volume.
- **JBOD** — Just a Bunch Of Disks. Два независимых диска без RAID, оба видны OS отдельно (`/dev/sdc`, `/dev/sdd`).
- **WAL-G** — утилита непрерывного бэкапа PostgreSQL в S3-совместимое хранилище.
- **PiTR** — Point-in-Time Recovery, восстановление БД на конкретную секунду.

## Ansible

- **Role** — модуль Ansible, лежит в `ansible/roles/NN-name/`.
- **Group** — группа узлов в `inventory/hosts.ini` (`app_nodes`, `db_nodes`, ...).
- **Meta-group** — группа из других групп (`stateful:children`).
- **host_vars** — переменные конкретного узла (`inventory/host_vars/<host>.yml`).
- **Handler** — отложенный обработчик (`notify:`).

## Аббревиатуры

- **SSOT** — Single Source of Truth.
- **ADR** — Architectural Decision Record.
- **DR** — Disaster Recovery.
- **HA** — High Availability.
- **NSG** — Azure Network Security Group.
- **THP** — Transparent Huge Pages.
- **CQRS** — Command Query Responsibility Segregation.
- **WG** — WireGuard.
