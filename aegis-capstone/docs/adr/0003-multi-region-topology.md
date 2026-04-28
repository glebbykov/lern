---
title: ADR-0003 — Распределение узлов по 3 Azure регионам
status: Accepted
date: 2026-03-08
related:
  - docs/topology.md
  - terraform/azure.tf
---

# ADR-0003: Распределение узлов по 3 Azure регионам

## Status
Accepted (2026-03-08).

## Context
В одном регионе у Azure Trial упёрлись в quota: `Standard_D2s_v5` capacity insufficient для 5 VM сразу. Нужно либо переключаться на другой инстанс-тип, либо разносить узлы по регионам. Заодно multi-region даёт реалистичный показ network-проблем (peering, latency, MTU).

## Decision
Узлы разносятся по трём регионам Asia-Pacific:

- **r1 (australiaeast):** `az-app`, `az-db` — высокий traffic между ingress и БД, общая подсеть.
- **r2 (australiasoutheast):** `az-kafka`, `az-etcd` — географически близко к r1, но другой регион.
- **r3 (southeastasia):** `az-storage` — DR-зона (бэкапы вне основной аварийной области).

VNet'ы пирятся: `r1↔r2`, `r1↔r3`. (Связность `r2↔r3` — отдельный вопрос, см. [ADR-0006](0006-r2-r3-peering.md).)

## Consequences

### Положительные
- **Реалистичная DR-топология.** Storage-tier физически вне основного blast radius.
- **Уход от quota.** Размазали capacity по регионам.
- **Учебная ценность.** Студент видит, что такое VNet peering, как latency растёт между регионами, как настраивается MTU.

### Отрицательные / Цена
- **Cross-region traffic billable.** Между регионами Azure берёт деньги за egress (правда, незаметные на capstone-нагрузке).
- **Latency.** r1↔r2 ~3ms, r1↔r3 ~80ms. Чувствительные операции (например, etcd consensus в будущем кластере) пострадают.
- **Сложность peering.** Каждая пара требует двух peering-объектов (см. `azure_virtual_network_peering`).

### Что станет проще / сложнее в будущем
- **Проще:** имитировать region failure для DR-теста — просто `az group delete -n aegis-v4-az-r3`.
- **Сложнее:** etcd-кластер из 3 узлов сейчас разнести по регионам — latency убьёт consensus. Решение: оставить etcd на одном узле в r2, либо использовать `--election-timeout` побольше.

## Alternatives considered

### Один регион + другой VM size
Отвергли: уход от standard `D2s_v5` ломает воспроизводимость (другой шаблон ресурсов на других машинах).

### Availability Zones внутри одного региона
Отвергли: AZ требует Standard SKU для всех ресурсов и доступны не во всех регионах Trial. Дороже и сложнее в нашем сетапе.

### Один регион + capacity reservation
Отвергли: reservation требует длинного коммитмента и недоступен на Trial.

## References
- `terraform/azure.tf` → `azurerm_resource_group.{r1,r2,r3}`.
- README §"Roadmap" → DR-концепция.
