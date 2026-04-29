---
title: Role 01-storage — диски, LVM, RAID, mounts
status: stable
audience: [ops, llm, contributors]
last_verified: 2026-04-29
related:
  - tasks/main.yml
  - handlers/main.yml
  - ../../inventory/host_vars/
  - ../../../docs/adr/0002-disk-isolation-per-database.md
---

# Role `01-storage`

Настраивает дисковую подсистему каждого узла. Полностью **data-driven**: ничего не зашито под конкретный хост, всё читается из per-host facts (`aegis_raid_devices`, `aegis_data_devices`), которые рендерит Terraform в `inventory/host_vars/<host>.yml`.

Один и тот же код одинаково работает для `az-db` (3 диска под БД) и для `az-storage` (RAID 5 из 3 дисков под бэкапы).

## Входные переменные (из host_vars)

| Переменная | Тип | Назначение |
|---|---|---|
| `aegis_raid_devices` | список путей `/dev/sdX` | какие диски собрать в RAID 5 (`/dev/md0`). Пустой список = без RAID. |
| `aegis_data_devices` | список объектов | финальные тома; см. ниже |

Каждый элемент `aegis_data_devices`:
```yaml
- name: pgsql                       # → vg_pgsql / lv_pgsql
  dev: /dev/sdc                     # block device
  fs: ext4                          # ext4 | xfs
  mount: /var/lib/postgresql        # точка монтирования
```

## Что делает за один прогон

```
для каждого узла:
  1. ставит lvm2 + xfsprogs
  2. рескан SCSI шины (Azure прикрепил диски на лету)
  3. если есть raid_devices → mdadm --create RAID 5 + запись в mdadm.conf
  4. для каждого data_device:
     pvcreate + vgcreate (vg_NAME)
     lvcreate -l 100%FREE (lv_NAME)
     mkfs.<ext4|xfs>
     mkdir <mount-point>
     mount + fstab
```

## Разбор задач

### 1. Установка зависимостей хранилища
```yaml
apt: name=[lvm2, xfsprogs] state=present
```
Ubuntu 22.04 cloud image не включает ни LVM-инструменты, ни XFS-утилиты по-умолчанию. Без них `community.general.lvg` и `filesystem` упадут. ext4 уже в ядре — для него ничего ставить не надо.

### 2. Рескан SCSI шины
```yaml
shell: for host in /sys/class/scsi_host/*; do echo "- - -" > $host/scan; done
changed_when: false
```
Managed disk прикрепляется к VM на лету (`azurerm_virtual_machine_data_disk_attachment`). Если Ansible начнёт работать **до** того, как ядро увидело диски, дальнейшие модули упадут с «device not found». Рескан гарантирует, что `/dev/sdc/d/e` видны.

`changed_when: false` — операция идемпотентна и не меняет состояние, не засоряем отчёты.

### 3. Установка `mdadm`
```yaml
apt: name=mdadm state=present
when: aegis_raid_devices | length > 0
```
RAID нужен только на `az-storage`. На остальных узлах список пустой → пакет не ставится. `default([])` — защита: если переменная не определена, интерпретируем как «нет RAID».

### 4. Создание RAID 5
```yaml
command: mdadm --create /dev/md0 --level=5 --raid-devices=N {{ devs }} --run
creates: /dev/md0
when: aegis_raid_devices | length >= 3
notify: update initramfs
```
- **RAID 5 (а не 0/1/10)** — для бэкапного узла важнее отказоустойчивость (терпит падение одного диска), чем максимальный throughput.
- **`creates: /dev/md0`** — идемпотентность: повторный прогон не пересоздаст RAID, не затрёт данные.
- **`length >= 3`** — RAID 5 физически требует минимум 3 диска.
- **`notify: update initramfs`** — initramfs должен знать про массив, чтобы собрать его на ранних этапах boot'а.

### 5. Сохранение конфигурации RAID
```yaml
shell: mdadm --detail --scan >> /etc/mdadm/mdadm.conf
```
**Без этой строки RAID не пересоберётся после ребута**: после рестарта диски могут получить другие имена `/dev/sd*`, и mdadm их не найдёт. Запись с UUID гарантирует пересборку независимо от порядка.

> **Слабое место:** `>>` (append) не идемпотентен — каждый прогон дописывает дублирующую строку. mdadm молча игнорирует дубли, но конфиг засоряется. Кандидат на рефакторинг через `lineinfile` (но `mdadm --detail --scan` — самый надёжный способ сгенерировать строку).

### 6. Создание Volume Group
```yaml
community.general.lvg:
  vg: "vg_{{ item.name }}"
  pvs: "{{ item.dev }}"
loop: aegis_data_devices
```
Для каждого устройства: `pvcreate` + `vgcreate vg_<name>`.

**Зачем LVM, а не голый `mkfs` на `/dev/sdX`:**
1. **Online-расширение.** `vgextend` + `lvextend` + `xfs_growfs` без unmount.
2. **Snapshot'ы.** LVM умеет в copy-on-write — пригодится для backup.
3. **Стабильные имена.** `/dev/vg_pgsql/lv_pgsql` не зависит от того, какое имя `/dev/sdX` диск получит после ребута.

Имена VG — `vg_<name>` (например, `vg_pgsql`, `vg_mongo`). Видишь VG — понимаешь, что внутри.

### 7. Создание Logical Volume
```yaml
community.general.lvol:
  vg: "vg_{{ item.name }}"
  lv: "lv_{{ item.name }}"
  size: 100%FREE
ignore_errors: yes
```
Одна LV на 100% VG. Размер уже задан в Terraform (`disk_size_gb`); дублировать в Ansible — нарушение SSOT.

> **Слабое место:** `ignore_errors: yes` маскирует баги (вне места, VG не существует и т.п.). Стоит заменить на узкий `failed_when:`. Сейчас это защита от случая «LV уже существует размером 100%» — модуль иногда падает при попытке «расширить» уже-полный том.

### 8. Форматирование
```yaml
filesystem: fstype={{ item.fs }} dev=/dev/vg_NAME/lv_NAME
```
Файловая система — из `host_vars`:
- **ext4** — для PG и Redis. Зрелая, журналируемая, хорошо работает на множестве small файлов с частым `fsync()`.
- **xfs** — для Mongo, Kafka, RAID5-бэкапов. Лучше для больших файлов, эффективнее allocation, MongoDB официально рекомендует XFS.

Модуль идемпотентен: на отформатированной LV ничего не делает.

### 9. Создание точек монтирования
```yaml
file: path={{ item.mount }} state=directory
```
Сам `mount` директорию не создаёт — упадёт, если её нет.

### 10. Монтирование с записью в fstab
```yaml
mount:
  path: "{{ item.mount }}"
  src: "/dev/vg_{{ item.name }}/lv_{{ item.name }}"
  state: mounted
```
`state: mounted` = смонтировать сейчас **и** записать в `/etc/fstab` (для авто-mount после ребута). Идемпотентен.

## Результат на разных узлах

**`az-db`:**
- `/dev/vg_pgsql/lv_pgsql` (ext4) → `/var/lib/postgresql`
- `/dev/vg_mongo/lv_mongo` (xfs) → `/var/lib/mongodb`
- `/dev/vg_redis/lv_redis` (ext4) → `/var/lib/redis`

**`az-kafka`:**
- `/dev/vg_kafka_jbod0/lv_kafka_jbod0` (xfs) → `/var/lib/kafka/data0`
- `/dev/vg_kafka_jbod1/lv_kafka_jbod1` (xfs) → `/var/lib/kafka/data1`

**`az-etcd`:**
- `/dev/vg_etcd/lv_etcd` (ext4) → `/var/lib/etcd`

**`az-storage`:**
- `/dev/{sdc,sdd,sde}` → `/dev/md0` (RAID 5)
- `/dev/vg_backups/lv_backups` (xfs) на `/dev/md0` → `/mnt/backups`

**`az-app`:**
- (текущий host_vars пуст) — диски под мониторинг сейчас не выделены, VictoriaMetrics использует os-disk.

## Связанные ADR

- [ADR-0002](../../../docs/adr/0002-disk-isolation-per-database.md) — почему 3 отдельных managed disk на `az-db`, а не один большой.

## Известные слабые места

1. **mdadm.conf append не идемпотентен** (задача 5).
2. **`ignore_errors: yes` в задаче 7** — маскирует реальные ошибки.
3. **PV сразу на raw device** (`/dev/sdc`, без раздела `/dev/sdc1`). На VM ок, на bare-metal BIOS иногда считает диск пустым.
4. **Нет cleanup-сценария.** Смена `fs` в host_vars (ext4 → xfs) — задача 8 откажется переформатировать. Потребуется ручной `wipefs -a`.
