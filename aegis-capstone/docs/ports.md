---
title: Каталог портов (SSOT)
status: stable
audience: [ops, llm, contributors]
last_verified: 2026-04-29
related:
  - ansible/roles/03-security/tasks/main.yml
  - terraform/azure.tf
---

# Каталог портов

Единственный источник правды для портов проекта. При изменении/добавлении порта правится **здесь**, остальные места ссылаются.

## Внешние (Internet → ingress-tier)

| Порт | Proto | Цель | Источник | Узел | Anchor |
|---|---|---|---|---|---|
| 22 | TCP | SSH (whitelisted) | `var.operator_ip` | `az-app` | <a id="ssh-22"></a>`#ssh-22` |
| 80 | TCP | HTTP (redirect → 443) | `0.0.0.0/0` | `az-app` | <a id="http-80"></a>`#http-80` |
| 443 | TCP | HTTPS / Nginx ingress | `0.0.0.0/0` | `az-app` | <a id="https-443"></a>`#https-443` |
| 3000 | TCP | Grafana UI | `var.operator_ip` | `az-app` | <a id="grafana-3000"></a>`#grafana-3000` |

## Внутренние (overlay / VNet)

| Порт | Proto | Сервис | Узел | Источник | Anchor |
|---|---|---|---|---|---|
| 5432 | TCP | PostgreSQL | `az-db` | `app_nodes`, `monitor_nodes` | <a id="postgresql-5432"></a>`#postgresql-5432` |
| 6379 | TCP | Redis | `az-db` | `app_nodes` | <a id="redis-6379"></a>`#redis-6379` |
| 27017 | TCP | MongoDB | `az-db` | `app_nodes` | <a id="mongodb-27017"></a>`#mongodb-27017` |
| 9092 | TCP | Kafka broker | `az-kafka` | `app_nodes` | <a id="kafka-9092"></a>`#kafka-9092` |
| 9093 | TCP | Kafka controller (KRaft) | `az-kafka` | `kafka_nodes` (self) | <a id="kafka-9093"></a>`#kafka-9093` |
| 2379 | TCP | etcd client API | `az-etcd` | `app_nodes` | <a id="etcd-2379"></a>`#etcd-2379` |
| 2380 | TCP | etcd peer (single-node — не используется) | `az-etcd` | — | <a id="etcd-2380"></a>`#etcd-2380` |

## Observability

| Порт | Proto | Сервис | Узел | Источник | Anchor |
|---|---|---|---|---|---|
| 8428 | TCP | VictoriaMetrics ingestion + query | `az-app` | `azure_nodes` (scrape source) | <a id="vm-8428"></a>`#vm-8428` |
| 9100 | TCP | node_exporter | все | `monitor_nodes` | <a id="node-exporter-9100"></a>`#node-exporter-9100` |

## Mesh

| Порт | Proto | Сервис | Узел | Источник | Anchor |
|---|---|---|---|---|---|
| 51820 | UDP | WireGuard | все | `azure_nodes` (peers) | <a id="wireguard-51820"></a>`#wireguard-51820` |

## Зарезервировано на будущее (не открывать сейчас)

| Порт | Назначение |
|---|---|
| 6443 | K8s API server (Phase 4) |
| 10250 | kubelet (Phase 4) |

---

## Где правила реально применяются

- **NSG (Azure)**: `terraform/azure.tf`, ресурс `azurerm_network_security_group.nsg1` и `nsg_internal`.
- **UFW (Ubuntu)**: `ansible/roles/03-security/tasks/main.yml` — правила по группам.

## Принципы

1. **Default deny.** Любой порт, отсутствующий в этой таблице, должен быть закрыт.
2. **Source-restricted.** Никогда `0.0.0.0/0` для внутренних сервисов — только конкретные группы Ansible.
3. **No port reuse.** Один порт = один сервис. Если хочется multiplexing — ставь Nginx/Envoy перед.
4. **Document before open.** Сначала строка в этой таблице, потом правило в `nsg`/`ufw`.
