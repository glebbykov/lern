---
title: ADR-0002 — Изоляция I/O через отдельные managed disks
status: Accepted
date: 2026-03-05
related:
  - ARCHITECTURE.md
  - ansible/roles/01-storage/
  - terraform/azure.tf
---

# ADR-0002: Изоляция I/O через отдельные managed disks на БД

## Status
Accepted (2026-03-05).

## Context
На `az-db` сосуществуют PostgreSQL, MongoDB и Redis. У каждой СУБД свой I/O-паттерн (PG — sequential WAL, Mongo — random reads, Redis — append-only). Конкуренция за IOPS на уровне shared контроллера блочных устройств может вызвать непредсказуемые latency-spikes.

Идеальный production: каждая БД на отдельной VM. У нас квоты Azure Trial этого не позволяют.

## Decision
На `az-db` прикрепляются **3 независимых managed disk** (LUN 0/1/2). Каждый диск становится отдельной LVM Volume Group (`vg_pgsql`, `vg_mongo`, `vg_redis`) с одной Logical Volume на 100% FREE и подходящей файловой системой:

- `/dev/sdc` → `vg_pgsql/lv_pgsql` → ext4 → `/var/lib/postgresql`
- `/dev/sdd` → `vg_mongo/lv_mongo` → xfs → `/var/lib/mongodb`
- `/dev/sde` → `vg_redis/lv_redis` → ext4 → `/var/lib/redis`

etcd вынесен на отдельную VM `az-etcd` (компромисс уже в этой части не нужен).

## Consequences

### Положительные
- **I/O queue per engine.** PG `fsync()` не блокирует Mongo cache miss.
- **Per-FS tuning.** ext4 для PG (mature, journaling), xfs для Mongo (лучше large files).
- **Гибкое расширение.** LVM позволяет grow VG добавлением PV без downtime.

### Отрицательные / Цена
- **Стоимость.** 3 managed disk вместо 1 = 3× плата за Premium_LRS.
- **Backup-стратегия сложнее.** Три точки failure вместо одной.
- **Mongo и WiredTiger делают direct I/O.** Часть тюнинга page cache теряется — но не критично.

### Что станет проще / сложнее в будущем
- **Проще:** подменить тип диска для одной БД (например, NVMe для PG), не трогая остальные.
- **Сложнее:** атомарный snapshot всего узла (теперь нужны coordinated snapshots на 3 диска).

## Alternatives considered

### Один большой disk + LVM с 3 LV на нём
Отвергли: общий I/O queue на одном блочном устройстве — проблема не решается логическим разделением.

### RAID 0 / RAID 5 поверх 3 дисков
Отвергли: RAID агрегирует throughput, но не изолирует latency. Один тяжёлый запрос Mongo всё равно бьёт по PG.

### Отдельные VM на каждую БД
Отвергли: Azure Trial квоты. Это **идеальный production-вариант**, см. `docs/PROJECT_PLAN.md` Phase 4 (HA).

## References
- README §"Строгая физическая изоляция I/O".
- `terraform/azure.tf` → `local.az_vms.db.disks`.
- `ansible/roles/01-storage/tasks/main.yml`.
