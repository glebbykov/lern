---
title: Индекс ADR
status: stable
audience: [llm, contributors, reviewers]
last_verified: 2026-04-29
---

# Architectural Decision Records

Список нетривиальных архитектурных решений проекта. Формат и правила — [docs/RULES.md §4](../RULES.md#4-когда-писать-adr). Шаблон — [template.md](template.md).

| № | Решение | Status |
|---|---|---|
| [0001](0001-databases-on-vm-not-k8s.md) | Базы данных — на VM, не в Kubernetes | Accepted |
| [0002](0002-disk-isolation-per-database.md) | Изоляция I/O через отдельные managed disks на БД | Accepted |
| [0003](0003-multi-region-topology.md) | Разнесение узлов по 3 Azure регионам | Accepted |
| [0004](0004-wireguard-mesh-zero-trust.md) | WireGuard full-mesh поверх VNet peering | Accepted |
| [0005](0005-remove-generate-tf-py.md) | Удаление `generate_tf.py`, `*.tf` — единственный источник правды | Accepted |
| [0006](0006-r2-r3-peering.md) | Связность r2↔r3 — добавить peering vs hub-and-spoke | Accepted |
| [0007](0007-local-stateful-in-compose.md) | Локальный stateful tier в docker-compose до Phase 3 | Accepted |

## Правила

- ADR не редактируются после `Accepted`. Для пересмотра — новый ADR со ссылкой `Supersedes: 000X`.
- Номера сквозные, не переиспользуются.
- Имя файла: `NNNN-kebab-case-title.md` (4 цифры, паддинг нулями).
