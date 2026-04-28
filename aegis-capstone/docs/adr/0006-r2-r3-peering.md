---
title: ADR-0006 — Связность r2↔r3 — peering vs hub-and-spoke
status: Open
date: 2026-04-29
related:
  - docs/topology.md
  - terraform/azure.tf
  - docs/adr/0004-wireguard-mesh-zero-trust.md
---

# ADR-0006: Связность r2↔r3 — peering vs hub-and-spoke

## Status
**Accepted** (реализовано через Вариант A).

## Context
В `terraform/azure.tf` сейчас есть VNet peering `r1↔r2` (`p12`/`p21`) и `r1↔r3` (`p13`/`p31`), но **нет** `r2↔r3`.

Из этого следует: узлы `az-kafka` и `az-etcd` (r2) не могут установить L3-связь с `az-storage` (r3) напрямую. WireGuard mesh-роль (см. [ADR-0004](0004-wireguard-mesh-zero-trust.md)) генерирует `Endpoint = <vnet-ip пира r3>:51820` для пиров на r2 — пакеты падают в blackhole.

Это блокирует сценарии:
- `az-kafka` → `az-storage` (отгрузка снапшотов на бэкапный узел).
- `az-etcd` → `az-storage` (snapshot etcd в DR-зону).

## Decision pending

Рассматриваем два варианта:

### Вариант A: добавить `r2↔r3` peering
Добавить ресурсы `azurerm_virtual_network_peering` `p23` и `p32`, аналогично существующим `p12/p21` и `p13/p31`.

### Вариант B: hub-and-spoke через `az-app`
Оставить peering как есть, но изменить WG-роль так, чтобы пиры из r2 и r3 общались **через** `az-app` (r1) как relay. Требует включения IP forwarding на `az-app` и переопределения `AllowedIPs` для соответствующих пиров.

## Trade-offs

| Аспект | Вариант A (peering) | Вариант B (hub-and-spoke) |
|---|---|---|
| Сложность реализации | Низкая (2 ресурса в TF) | Высокая (sysctl, маршруты, перерасчёт WG-конфига) |
| Latency r2↔r3 | Прямой путь | r2 → r1 → r3 (двойной hop) |
| Стоимость egress | r2↔r3 cross-region | r2↔r1 + r1↔r3 cross-region |
| Single point of failure | Нет | Да (`az-app` упал → r2 и r3 изолированы) |
| Совпадение с дизайном «mesh» | Да | Нет (это уже не mesh, а star) |
| Учебная ценность | Чистая mesh-топология | Демонстрация маршрутизации |

## Рекомендация

**Вариант A (peering r2↔r3)** — правильный выбор для текущего этапа. Дешевле в реализации, не ломает идею full-mesh из [ADR-0004](0004-wireguard-mesh-zero-trust.md), нет SPOF.

Вариант B рассматривать только если хочется специально продемонстрировать routing/forwarding в учебных целях — но тогда честнее назвать это hub-and-spoke и пересмотреть [ADR-0004](0004-wireguard-mesh-zero-trust.md).

## Consequences (если будет принят Вариант A)

### Положительные
- Полная mesh-связность.
- WG mesh поднимается без хаков.

### Отрицательные / Цена
- Незначительный cross-region egress между r2 и r3.
- Ещё 2 peering-ресурса в state.

## References
- `terraform/azure.tf` строки `azurerm_virtual_network_peering.{p12,p21,p13,p31}` — существующие, как образец.
- [ADR-0004](0004-wireguard-mesh-zero-trust.md) — WireGuard mesh, который страдает от этой дыры.
