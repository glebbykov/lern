# 01-storage/tasks/main.yml — разбор по задачам

Роль настраивает дисковую подсистему каждого узла. Полностью data-driven: ничего не зашито под конкретный хост, всё читается из per-host facts (`aegis_raid_devices`, `aegis_data_devices`), которые рендерит Terraform в `inventory/host_vars/<host>.yml`. Один и тот же код одинаково работает для az-db (диски под БД) и для az-storage (RAID из дисков под бэкапы).

---
## Задача 1 — Установка зависимостей хранилища (строки 2–6)
`apt: name=[lvm2, xfsprogs] state=present update_cache: yes`

**Что делает:** ставит пакеты `lvm2` (управление LVM — VG/LV/PV) и `xfsprogs` (утилиты для XFS — mkfs.xfs, xfs_repair).
**Зачем:** Ubuntu 22.04 cloud image не включает ни LVM-инструменты, ни XFS-утилиты по-умолчанию. Без них дальнейшие модули `community.general.lvg` и `filesystem` упадут.
**Почему именно эти два:** ext4 уже в ядре + базовых утилитах — для него ничего ставить не надо. XFS используется на узлах с большими файлами (Mongo, Kafka, бэкапы), LVM нужен везде.

---
## Задача 2 — Рескан SCSI шины (строки 8–13)
```bash
shell: |
  for host in /sys/class/scsi_host/*; do echo "- - -" > $host/scan; done
changed_when: false
```

**Что делает:** триггерит ядро на повторное сканирование SCSI-шины — заставляет Linux обнаружить только что подключённые managed disks.
**Зачем:** в Azure managed disk прикрепляется к VM на лету. Если Ansible начнёт работать до того, как ядро увидело диски, модули упадут с «device not found».
**Почему changed_when: false:** операция идемпотентная. Без этого флага Ansible считал бы каждый прогон как «changed».

---
## Задача 3 — Установка mdadm (строки 15–19)
`apt: name=mdadm state=present`
`when: aegis_raid_devices | default([]) | length > 0`

**Что делает:** ставит mdadm (управление software RAID).
**Зачем условие:** RAID нужен только на узлах, где он определен. Не таскаем зависимости туда, где они не нужны. `default([])` — защита от неопределенной переменной.

---
## Задача 4 — Создание RAID 5 (строки 21–31)
```yaml
command: >-
  mdadm --create --verbose /dev/md0
    --level=5
    --raid-devices={{ aegis_raid_devices | length }}
    {{ aegis_raid_devices | join(' ') }}
    --run
args:
  creates: /dev/md0
when: aegis_raid_devices | default([]) | length >= 3
notify: update initramfs
```

**Что делает:** собирает software RAID 5 из всех дисков из `aegis_raid_devices` в `/dev/md0`.
**Зачем RAID 5:** N дисков, ёмкость N−1, толерантность к отказу одного диска. Для бэкапов важна отказоустойчивость. `--run` — игнорирует подтверждение.
**Идемпотентность:** `creates: /dev/md0` гарантирует, что массив не будет пересоздан с затиранием данных.
**notify:** триггерит хэндлер `update-initramfs -u`, чтобы загрузчик знал про RAID.

---
## Задача 5 — Сохранение конфигурации RAID (строки 33–41)
`shell: mdadm --detail --scan >> /etc/mdadm/mdadm.conf`

**Что делает:** выводит описание массивов и дописывает в `mdadm.conf`.
**Зачем:** без этой строки RAID не пересоберётся после ребута, так как имена дисков могут поменяться. UUID фиксирует массив.
**Известная слабость:** `>>` (append) не идемпотентно — каждый прогон дописывает строку. На практике дубли игнорируются mdadm.

---
## Задача 6 — Создание Volume Group (строки 43–49)
`community.general.lvg:`
`vg: "vg_{{ item.name }}"`

**Зачем LVM:**
1. Расширяемость онлайн (vgextend, lvextend, xfs_growfs).
2. Snapshot'ы (удобно для бэкапов).
3. Стабильные имена (`/dev/vg_pgsql/lv_pgsql` вместо `/dev/sdc`).

---
## Задача 7 — Создание Logical Volume (строки 51–59)
`community.general.lvol:`
`size: 100%FREE`
`ignore_errors: yes`

**Зачем 100%FREE:** Размер диска задан в Terraform. LV занимает всё доступное место, так как на диске одна БД.
**Слабое место:** `ignore_errors: yes` скрывает реальные ошибки. Это защита от бага модуля `lvol` при повторных прогонах, но стоило бы использовать `failed_when:`.

---
## Задача 8 — Форматирование (строки 61–67)
`filesystem:`

**Зачем разные ФС:**
- **ext4** — PostgreSQL и Redis (мелкие файлы, fsync).
- **xfs** — MongoDB, Kafka, бэкапы (большие файлы, parallel I/O, рекомендация MongoDB).

---
## Задача 9 и 10 — Монтирование (строки 69–85)
`file: path={{ item.mount }} state=directory`
`mount: state=mounted`

**Что делает:** Создает директорию, монтирует LV и дописывает запись в `/etc/fstab` для авто-монтирования при ребуте (`state: mounted`).

---
## Слабые места (Technical Debt)
1. Задача 5 — append в `mdadm.conf` не идемпотентен.
2. Задача 7 — `ignore_errors: yes` маскирует баги (нужен `failed_when:`).
3. PV создаются сразу на raw device (например, `/dev/sdc`), без разделов. Для Capstone и VM это ок, но на bare-metal лучше создавать таблицы разделов.
4. Нет cleanup-сценария. При смене типа ФС Ansible упадёт. Потребуется ручной `wipefs`.
