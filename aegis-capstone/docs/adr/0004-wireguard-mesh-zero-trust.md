---
title: ADR-0004 — WireGuard full-mesh поверх VNet peering
status: Accepted
date: 2026-04-15
related:
  - docs/topology.md
  - ansible/roles/05-overlay-network/
---

# ADR-0004: WireGuard full-mesh поверх VNet peering

## Status
Accepted (2026-04-15).

## Context
NSG в Azure разрешает весь traffic из `10.0.0.0/8` внутри VNet — это широкое правило, нарушающее принцип Zero-Trust. Нужна плоскость управления, в которой сервисы достижимы **только** между взаимно аутентифицированными узлами, без доверия к VNet/peering.

Альтернативные подходы — service mesh (Istio, Linkerd), mTLS на уровне приложений, IPsec — либо тяжёлые, либо требуют PKI-инфраструктуры, которой у capstone нет.

## Decision
Все 5 узлов входят в WireGuard full-mesh поверх существующих VNet peering:

- Подсеть overlay: `10.100.0.0/24`.
- Каждый узел → keypair, конфиг `/etc/wireguard/wg0.conf` рендерится Ansible-ролью `05-overlay-network`.
- `Endpoint` пира = его реальный VNet-IP (`ansible_host`).
- `AllowedIPs` пира = его overlay IP (`10.100.0.X/32`).
- `PersistentKeepalive = 25` для удержания UDP-туннеля.

**Все приложения слушают на overlay IP**, не на VNet IP. Это переносит Zero-Trust с уровня сети на уровень криптографических ключей.

## Consequences

### Положительные
- **Zero-Trust по-умолчанию.** Узел без WG-ключа не достучится ни до одной БД, даже имея VNet-доступ.
- **Транспортная плоскость зашифрована.** Mongo/Redis/PG, у которых TLS opt-in, бесплатно получают шифрование канала.
- **Cross-region работает прозрачно.** Mesh не зависит от того, в одном ли регионе пиры.
- **Простота реализации.** WG работает в kernel-space, конфиг — десятки строк.

### Отрицательные / Цена
- **Хрупкость к peering.** Если VNet peering недоступен (см. [ADR-0006](0006-r2-r3-peering.md)) — соответствующий пир WG не поднимется.
- **Нет автоматической ротации ключей.** Ключ скомпрометирован — нужно вручную пересоздать и raskat'ить.
- **Один пир упал → mesh не fail-fast.** PersistentKeepalive обнаружит через ~25 секунд, не мгновенно.
- **Overlay IP-схема статичная.** Изменение порядка узлов в Ansible inventory переназначает IP — это легко сломать.

### Что станет проще / сложнее в будущем
- **Проще:** добавить новый узел — одна строка в inventory + повторный прогон роли.
- **Сложнее:** мигрировать на Istio в Kubernetes-эпохе — потребуется параллельный mesh для миграции.

## Alternatives considered

### Просто полагаться на NSG + VNet peering
Отвергли: широкие правила `10.0.0.0/8 → all ports`, любой compromise одного узла даёт lateral movement.

### IPsec
Отвергли: тяжёлая конфигурация, IKE-инициаторы требуют отдельной службы, hard to debug.

### mTLS на уровне приложений
Отвергли: PKI инфраструктура (CA, ротация, OCSP) — отдельный проект. Кроме того, Redis и MongoDB конфиг под mTLS нетривиален.

### Tailscale / Headscale
Отвергли (для capstone): добавляет внешнюю зависимость, прячет важные детали (key-exchange, NAT traversal). Цель проекта — показать понимание low-level.

## References
- `ansible/roles/05-overlay-network/tasks/main.yml`.
- `ansible/roles/05-overlay-network/templates/wg0.conf.j2`.
- [WireGuard whitepaper](https://www.wireguard.com/papers/wireguard.pdf).
