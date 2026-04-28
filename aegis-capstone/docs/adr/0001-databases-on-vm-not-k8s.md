---
title: ADR-0001 — Базы данных на VM, не в Kubernetes
status: Accepted
date: 2026-03-01
related:
  - ARCHITECTURE.md
  - ansible/roles/06-stateful-tier/
---

# ADR-0001: Базы данных на VM, не в Kubernetes

## Status
Accepted (2026-03-01).

## Context
Архитектурный комитет Aegis Pay требует физической изоляции узлов по типу нагрузки. Stateful-tier (PostgreSQL, MongoDB, Redis, etcd) можно либо положить в будущий Kubernetes-кластер вместе с приложениями, либо вынести на классические VM.

Базы — критичны по latency и imbalanced на ресурсы (cache-bound для Redis/Mongo, I/O-bound для PG). Их соседство с произвольными приложениями в shared kernel'е — источник несвязанных регрессий.

## Decision
Базы данных разворачиваются **на отдельных VM** (`az-db`, `az-kafka`, `az-etcd`). Kubernetes (когда появится) — только на ingress-tier (`az-app`).

## Consequences

### Положительные
- **Predictable I/O.** Никаких "noisy neighbors" — на узле БД нет других подов.
- **Kernel tuning.** `vm.zone_reclaim_mode`, отключение THP, `vm.dirty_ratio` — настраиваются под конкретный движок (см. `02-kernel`).
- **Прямой блочный доступ.** Нет CSI-overhead, никаких volume plugin'ов.
- **Простота backup/restore.** PG dump / WAL-G / mongodump работают на хосте напрямую.

### Отрицательные / Цена
- **Нет автоматического self-healing** для VM — failure VM = ручной recovery (или Patroni в будущем).
- **Нет horizontal autoscaling** — ёмкость задаётся при провижне.
- **Дублируется два рантайма** — VM (для stateful) и K8s (для apps).

### Что станет проще / сложнее в будущем
- **Проще:** добавить read-replica PG / арбитра Mongo — это просто новая VM.
- **Сложнее:** мигрировать БД в K8s, если когда-нибудь решим — придётся переучивать команду на operator-pattern.

## Alternatives considered

### Всё в Kubernetes (StatefulSet + PVC)
Отвергли: I/O через CSI медленнее, kernel tuning невозможен per-pod, scheduler может посадить шумного соседа.

### Managed databases (Azure Database for PostgreSQL и пр.)
Отвергли как учебный компромисс: цель проекта — показать понимание low-level (kernel, диски, RAID), managed-сервис эту часть скрывает.

## References
- README §1 — обоснование "почему не K8s" в исходной формулировке.
- `ansible/roles/02-kernel/tasks/main.yml` — kernel tuning, который невозможен в K8s.
