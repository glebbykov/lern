# Лабораторная работа: Управление дисковой подсистемой Linux

**Сервер:** `mount` — 34.30.107.29  
**Подключение:** `ssh -i id_ed25519 msherdev@34.30.107.29`  
**Уровень:** Middle / Senior Linux Administrator

---

## Предварительная установка пакетов

```bash
sudo apt-get update
sudo apt-get install -y \
  xfsprogs btrfs-progs mdadm lvm2 \
  sysstat fio lsof parted
```

> На Debian 12 `fdisk`, `lsof` и ряд других утилит не входят в базовую
> систему — без этого шага часть команд не найдётся.

---

## Стартовая проверка

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
```

```
NAME     SIZE TYPE FSTYPE MOUNTPOINT
sda       10G disk                    <- рабочий
sdb       10G disk                    <- рабочий
sdc       10G disk                    <- рабочий
sdd       20G disk                    <- системный, не трогать
├─sdd1  19.9G part ext4   /
├─sdd14    3M part
└─sdd15  124M part vfat   /boot/efi
sde       10G disk                    <- рабочий
sdf       10G disk                    <- рабочий
sdg       10G disk                    <- рабочий
sdh       10G disk                    <- рабочий
sdi       10G disk                    <- рабочий
```

> **Важно:** GCP не гарантирует порядок имён дисков — системный диск
> может оказаться `sda`, `sdb` или `sdd`. Всегда проверяйте `lsblk`
> перед началом работы и ориентируйтесь на размер (20G = системный).

---

## Модуль 1: Виртуальные файловые системы в оперативной памяти и ядре

### Теория для изучения перед модулем

- Иерархия файловой системы Linux (FHS): назначение `/proc`, `/sys`, `/dev`, `/run`
- Что такое VFS (Virtual File System) в ядре Linux
- Архитектура ядра: пространство ядра vs пространство пользователя
- Понятие файлового дескриптора и его жизненный цикл
- Принцип работы `tmpfs` и отличие от дисковых ФС
- I/O scheduler: зачем нужен, какие бывают (CFQ, Deadline, BFQ, none)
- Многоочередная блочная подсистема ядра (blk-mq)

---

**Цель:** Понять работу файловых систем, которые не используют физические диски,
но критичны для работы ОС.

---

### 1.1 Исследование procfs

`/proc` — виртуальная файловая система, предоставляющая доступ к состоянию ядра и процессов. Файлы здесь генерируются ядром на лету при каждом чтении.

```bash
# Посмотреть всё что смонтировано в системе
cat /proc/mounts

# Найти только виртуальные ФС (без физических дисков)
cat /proc/mounts | grep -v ^/dev

# Информация о процессоре
cat /proc/cpuinfo | grep "model name" | head -1

# Информация об оперативной памяти
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable"

# Текущие блочные устройства глазами ядра
cat /proc/partitions

# Статистика I/O по дискам (отсюда берёт данные iostat)
cat /proc/diskstats | grep -E "sda|sdb|sdd"
```

```bash
# Посмотреть I/O статистику дисков в реальном времени
iostat -x 1 5
```

---

### 1.2 Исследование sysfs

`/sys` — экспортирует иерархию объектов ядра (устройства, драйверы, шины).
В отличие от `/proc`, здесь можно не только читать, но и **управлять** устройствами.

```bash
# Посмотреть все блочные устройства
ls /sys/block/

# Размер диска sda (надёжнее через lsblk):
lsblk -o NAME,SIZE /dev/sda | head -2

# Тип диска: 0 = SSD/виртуальный, 1 = HDD
cat /sys/block/sda/queue/rotational

# Глубина очереди запросов
cat /sys/block/sda/queue/nr_requests

# Оптимальный размер блока для чтения (в байтах)
cat /sys/block/sda/queue/optimal_io_size

# Максимальный размер одного запроса к диску
cat /sys/block/sda/queue/max_sectors_kb
```

---

### 1.3 Управление планировщиком I/O

| Планировщик | Применение |
|-------------|-----------|
| `mq-deadline` | Универсальный, хорош для HDD и SSD |
| `none` | Без сортировки, оптимален для SSD/NVMe |
| `kyber` | Минимальные задержки, для SSD |
| `bfq` | Справедливое распределение, для десктопов |

```bash
# Посмотреть доступные планировщики (активный — в квадратных скобках)
cat /sys/block/sda/queue/scheduler
# На GCP (виртуальные диски): [none] mq-deadline
# На физических HDD:           [mq-deadline] none kyber bfq

# На GCP диски уже используют none — оптимально для SSD.
# Для демонстрации переключим на mq-deadline:
echo mq-deadline | sudo tee /sys/block/sda/queue/scheduler

# Проверить
cat /sys/block/sda/queue/scheduler
# Вывод: [mq-deadline] none

# Вернуть обратно
echo none | sudo tee /sys/block/sda/queue/scheduler
```

> Изменение через `/sys` действует до перезагрузки. Для постоянного эффекта
> нужно udev-правило в `/etc/udev/rules.d/`.

```bash
# Сделать изменение постоянным через udev:
echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", \
  ATTR{queue/scheduler}="none"' | sudo tee /etc/udev/rules.d/60-io-scheduler.rules
```

---

### 1.4 Работа с tmpfs (RAM-диск)

`tmpfs` — файловая система целиком в оперативной памяти. Данные исчезают при
размонтировании или перезагрузке.

```bash
# Создать точку монтирования
sudo mkdir -p /mnt/ramdisk

# Смонтировать tmpfs объёмом 2G
sudo mount -t tmpfs -o size=2G tmpfs /mnt/ramdisk

# Убедиться что смонтирована
df -h /mnt/ramdisk
# tmpfs  2.0G  0  2.0G  0% /mnt/ramdisk

# Запомнить значение used RAM до записи
free -h
```

**Тест скорости записи в RAM vs диск:**

```bash
# Запись в tmpfs (RAM) — ожидаем несколько GB/s
sudo dd if=/dev/zero of=/mnt/ramdisk/testfile bs=1M count=1000 conv=fdatasync status=progress

# Для сравнения — запись на физический диск sdd (свободный диск, не используется в других модулях)
sudo dd if=/dev/zero of=/dev/sdd bs=1M count=1000 oflag=direct status=progress
# Ожидаем: ~100-200 MB/s — в разы медленнее RAM
```

```bash
# Убедиться что данные в памяти — RAM уменьшилась
free -h
# Колонка used выросла на ~1G

# Тест чтения из RAM
sudo dd if=/mnt/ramdisk/testfile of=/dev/null bs=1M status=progress

# Размонтировать — данные уничтожены мгновенно
sudo umount /mnt/ramdisk
free -h
# RAM освободилась
```

**Практический кейс — tmpfs для сессий PHP:**

```bash
# (только для демонстрации)
# mount -t tmpfs -o size=512M,mode=1777 tmpfs /var/lib/php/sessions
```

**Контрольные вопросы:**
1. Что произойдёт с файлами в `/mnt/ramdisk` после `sudo reboot`?
2. Почему `/run` и `/tmp` в современных дистрибутивах монтируются как `tmpfs`?
3. Чем `tmpfs` отличается от `ramfs`? Что опаснее использовать и почему?
4. Как посмотреть какие виртуальные ФС смонтированы прямо сейчас?

---

## Модуль 2: Базовая разметка, классические ФС (ext4, xfs) и персистентность

### Теория для изучения перед модулем

- Таблицы разделов: MBR vs GPT — отличия, ограничения, применение
- Структура GPT: Primary/Backup GPT header, Partition Entry Array
- Журналируемые файловые системы: зачем нужен журнал, режимы (`data=ordered`, `data=journal`, `data=writeback`)
- Структура ext4: superblock, block groups, inode table, extent tree
- Структура xfs: AG (Allocation Groups), B-tree индексы
- Назначение `/etc/fstab`: поля, опции монтирования, порядок проверки ФС (fsck)
- UUID vs PATH vs LABEL для идентификации устройств
- Понятие inode: что хранит, как связан с файлом, почему может кончиться раньше места

---

**Цель:** Научиться базово готовить диски, форматировать их и обеспечивать
автоматическое монтирование при загрузке ОС.

**Диск:** `sda` (10G)

---

### 2.1 Разметка диска GPT через parted

```bash
# Убедиться что диск пустой
sudo parted /dev/sda print 2>&1 | head -5

# Создать GPT таблицу разделов и два раздела по 5G
sudo parted /dev/sda --script \
  mklabel gpt \
  mkpart primary 1MiB 5GiB \
  mkpart primary 5GiB 100%

# Уведомить ядро об изменении таблицы разделов (обязательно!)
sudo partprobe /dev/sda

# Проверить результат
lsblk /dev/sda
# sda    10G disk
# ├─sda1  5G part
# └─sda2  5G part

sudo parted /dev/sda print
```

> Для интерактивной работы также доступен `sudo fdisk /dev/sda`
> (после установки: `sudo apt-get install -y fdisk`).

---

### 2.2 Создание файловых систем

```bash
# Форматировать sda1 в ext4 (-L задаёт метку)
sudo mkfs.ext4 -L ext4-data /dev/sda1

# Форматировать sda2 в xfs
sudo mkfs.xfs -L xfs-data /dev/sda2

# Убедиться что ФС созданы
lsblk -o NAME,SIZE,FSTYPE,LABEL /dev/sda
```

**Изучим параметры созданных ФС:**

```bash
# Параметры ext4: inodes, блоки, журнал
sudo tune2fs -l /dev/sda1 | grep -E "Inode|Block|Journal|mount"

# Параметры xfs (только после монтирования — аргумент точка монтирования)
# sudo xfs_info /data/xfs    <- выполнить после раздела 2.3
```

---

### 2.3 Монтирование и идентификация по UUID

```bash
# Получить UUID обоих разделов
sudo blkid /dev/sda1 /dev/sda2

# Только UUID, без лишнего
sudo blkid -s UUID -o value /dev/sda1
sudo blkid -s UUID -o value /dev/sda2

# Создать точки монтирования
sudo mkdir -p /data/ext /data/xfs

# Смонтировать
sudo mount /dev/sda1 /data/ext
sudo mount /dev/sda2 /data/xfs

df -h /data/ext /data/xfs
mount | grep sda

# Параметры xfs теперь доступны
sudo xfs_info /data/xfs

# Записать тестовые данные
echo "ext4 partition test" | sudo tee /data/ext/README
echo "xfs partition test"  | sudo tee /data/xfs/README

# Размонтировать перед добавлением в fstab
sudo umount /data/ext /data/xfs
```

---

### 2.4 Постоянное монтирование через fstab

```bash
cat /etc/fstab

# Получить UUID и добавить в fstab
UUID_EXT=$(sudo blkid -s UUID -o value /dev/sda1)
UUID_XFS=$(sudo blkid -s UUID -o value /dev/sda2)

echo "UUID=${UUID_EXT}  /data/ext  ext4  defaults  0  2" | sudo tee -a /etc/fstab
echo "UUID=${UUID_XFS}  /data/xfs  xfs   defaults  0  2" | sudo tee -a /etc/fstab

tail -3 /etc/fstab
```

**Критическая проверка перед перезагрузкой:**

```bash
# Смонтировать всё из fstab — если ошибка, исправить до reboot
sudo mount -a

df -h /data/ext /data/xfs
```

---

### 2.5 Сравнение производительности ext4 vs xfs

```bash
# Последовательная запись — ext4
sudo dd if=/dev/zero of=/data/ext/testfile bs=1M count=2000 conv=fdatasync status=progress

# Последовательная запись — xfs
sudo dd if=/dev/zero of=/data/xfs/testfile bs=1M count=2000 conv=fdatasync status=progress

# Случайная запись 4K — ext4
sudo fio --name=rw-ext4 --filename=/data/ext/fiotest \
  --rw=randwrite --bs=4k --size=1G --numjobs=4 --runtime=30 \
  --group_reporting 2>/dev/null | grep -E "WRITE|iops"

# Случайная запись 4K — xfs
sudo fio --name=rw-xfs --filename=/data/xfs/fiotest \
  --rw=randwrite --bs=4k --size=1G --numjobs=4 --runtime=30 \
  --group_reporting 2>/dev/null | grep -E "WRITE|iops"

sudo rm -f /data/ext/testfile /data/ext/fiotest
sudo rm -f /data/xfs/testfile /data/xfs/fiotest
```

**Ключевые различия ext4 vs xfs:**

| Характеристика | ext4 | xfs |
|----------------|------|-----|
| Inodes | Фиксированные при mkfs | Динамические |
| Уменьшение ФС | Поддерживается | Не поддерживается |
| Расширение онлайн | `resize2fs` | `xfs_growfs` |
| Макс. размер файла | 16 ТБ | 8 ЭБ |
| Производительность на больших файлах | Хорошая | Отличная |
| Журналирование | Metadata + data | Только metadata по умолчанию |

**Контрольные вопросы:**
1. Почему использование `/dev/sda2` вместо UUID в fstab — антипаттерн?
2. Что означают поля `0 2` в конце строки fstab?
3. Что произойдёт если сделать ошибку в fstab и перезагрузить сервер?
4. Можно ли уменьшить xfs после создания? А ext4?
5. Чем отличается `defaults` от `noatime` в опциях монтирования?

---

## Модуль 3: Продвинутые возможности Btrfs

### Теория для изучения перед модулем

- Copy-on-Write (CoW): принцип работы, преимущества и недостатки
- B-tree структуры данных в Btrfs (в отличие от extent-based ext4)
- Понятие subvolume vs обычная директория
- Механизм snapshot в CoW-системах: почему не копирует данные при создании
- Встроенный RAID в Btrfs: отличие от mdadm (уровень ФС vs уровень блочного устройства)
- Scrub в Btrfs: проверка целостности данных через контрольные суммы
- Ограничения Btrfs RAID 5/6 (известные баги, не рекомендуется для production)

---

**Цель:** Изучить файловую систему нового поколения со встроенными функциями
управления томами и Copy-on-Write.

**Диски:** `sdb` (10G), `sdc` (10G)

---

### 3.1 Создание Btrfs RAID 1

```bash
# Убедиться что диски пустые
sudo wipefs -a /dev/sdb /dev/sdc

# Создать Btrfs пул с RAID 1
# -m raid1 = метаданные зеркалируются
# -d raid1 = данные зеркалируются
sudo mkfs.btrfs -m raid1 -d raid1 -L btrfs-pool /dev/sdb /dev/sdc

# Смонтировать (можно указать любой из дисков пула)
sudo mkdir -p /mnt/btrfs_pool
sudo mount /dev/sdb /mnt/btrfs_pool

# Посмотреть структуру пула
sudo btrfs filesystem show /mnt/btrfs_pool
sudo btrfs filesystem usage /mnt/btrfs_pool

# Проверить профиль RAID
sudo btrfs filesystem df /mnt/btrfs_pool
# Data, RAID1: ...
# Metadata, RAID1: ...
```

---

### 3.2 Создание и монтирование субтомов

```bash
# Создать субтомы
sudo btrfs subvolume create /mnt/btrfs_pool/@data
sudo btrfs subvolume create /mnt/btrfs_pool/@logs

sudo btrfs subvolume list /mnt/btrfs_pool

# Записать данные которые будем защищать снимком
sudo bash -c 'for i in $(seq 1 10); do
  echo "Important file $i: $(date)" | tee /mnt/btrfs_pool/@data/file_$i.txt
done'
sudo dd if=/dev/urandom of=/mnt/btrfs_pool/@data/bigfile.bin bs=1M count=200 status=progress

ls -lh /mnt/btrfs_pool/@data/
```

Размонтировать общий пул и смонтировать субтомы отдельно:

```bash
sudo umount /mnt/btrfs_pool

sudo mkdir -p /data/btrfs_data /data/btrfs_logs

# Смонтировать субтомы через опцию subvol=
sudo mount -o subvol=@data /dev/sdb /data/btrfs_data
sudo mount -o subvol=@logs /dev/sdb /data/btrfs_logs

ls /data/btrfs_data/   # только файлы @data
ls /data/btrfs_logs/   # пустой @logs

echo "2026-04-12 service started" | sudo tee /data/btrfs_logs/app.log

sudo btrfs filesystem usage /data/btrfs_data
```

---

### 3.3 Снапшоты и восстановление данных

```bash
# Смонтировать корень пула для управления снапшотами
sudo mount -o subvol=/ /dev/sdb /mnt/btrfs_pool

sudo btrfs subvolume list /mnt/btrfs_pool

# Создать Read-Only снапшот
SNAP_NAME="@data_snap_$(date +%Y%m%d_%H%M%S)"
sudo btrfs subvolume snapshot -r /mnt/btrfs_pool/@data /mnt/btrfs_pool/${SNAP_NAME}

sudo btrfs subvolume list /mnt/btrfs_pool

# Сколько места занимает снапшот?
sudo btrfs subvolume show /mnt/btrfs_pool/${SNAP_NAME}
# Exclusive referenced size будет ~0 — снапшот ничего не скопировал!
```

**Симуляция катастрофы:**

```bash
sudo rm -rf /data/btrfs_data/*
ls /data/btrfs_data/   # пусто!
```

**Восстановление из снапшота:**

```bash
# Вариант 1: отдельные файлы
sudo cp -a /mnt/btrfs_pool/${SNAP_NAME}/file_1.txt /data/btrfs_data/

# Вариант 2: полное восстановление через rsync
sudo rsync -av /mnt/btrfs_pool/${SNAP_NAME}/ /data/btrfs_data/

ls -lh /data/btrfs_data/
cat /data/btrfs_data/file_1.txt
```

**Управление снапшотами:**

```bash
# Все снапшоты
sudo btrfs subvolume list -s /mnt/btrfs_pool

# Изменить RO снапшот в RW
sudo btrfs property set /mnt/btrfs_pool/${SNAP_NAME} ro false

# Удалить снапшот
sudo btrfs subvolume delete /mnt/btrfs_pool/${SNAP_NAME}

sudo btrfs filesystem usage /mnt/btrfs_pool
```

**Контрольные вопросы:**
1. Почему снапшот в Btrfs занимает ~0 байт сразу после создания?
2. Что произойдёт если один из дисков RAID 1 в Btrfs выйдет из строя?
3. В чём разница между `mkfs.btrfs /dev/sdb /dev/sdc` (JBOD) и `mkfs.btrfs -d raid1 /dev/sdb /dev/sdc`?
4. Можно ли монтировать Btrfs RAID 1 если один из дисков недоступен?

---

## Модуль 4: Программный RAID (mdadm)

### Теория для изучения перед модулем

- Уровни RAID: 0, 1, 5, 6, 10 — принципы работы, вычисление полезного объёма
- Паритет в RAID 5/6: алгоритм XOR, распределение паритетных блоков
- Chunk size (размер блока): влияние на производительность, как выбрать
- Понятие деградированного режима: что происходит с производительностью и доступностью
- Hot spare vs Cold spare: разница в времени восстановления
- Rebuild process: влияние на производительность, read-error during rebuild
- Superblock mdadm: что хранит, версии (0.9, 1.0, 1.1, 1.2)
- Почему RAID — это не резервное копирование (защищает от отказа железа, не от удаления/порчи данных)

---

**Цель:** Обеспечить отказоустойчивость на блочном уровне.

**Диски:** `sde`, `sdf`, `sdg` — рабочие; `sdh` — горячий резерв

---

### 4.1 Подготовка дисков

```bash
# Очистить возможные старые суперблоки mdadm
sudo mdadm --zero-superblock /dev/sde /dev/sdf /dev/sdg /dev/sdh 2>/dev/null
sudo wipefs -a /dev/sde /dev/sdf /dev/sdg /dev/sdh

mdadm --version
```

---

### 4.2 Создание RAID 5 с горячим резервом

```bash
sudo mdadm --create --verbose /dev/md0 \
  --level=5 \
  --raid-devices=3 /dev/sde /dev/sdf /dev/sdg \
  --spare-devices=1 /dev/sdh

# Посмотреть начало синхронизации
cat /proc/mdstat
```

Вы увидите:
```
md0 : active raid5 sdh[3](S) sdg[2] sdf[1] sde[0]
      20953088 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/3] [UUU]
      [=>...................]  resync =  5.1% finish=5.3min speed=20882K/sec
```

```bash
# Следить за синхронизацией
watch -n 2 cat /proc/mdstat

# RAID работает во время синхронизации — не нужно ждать
sudo mdadm --detail /dev/md0
```

---

### 4.3 Форматирование и монтирование RAID

```bash
sudo mkfs.ext4 -L raid5-data /dev/md0

sudo mkdir -p /mnt/raid5
sudo mount /dev/md0 /mnt/raid5

df -h /mnt/raid5
# ~20G (3 диска по 10G, 1 диск под паритет = 20G полезного)

# Сохранить конфигурацию для автосборки при загрузке
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u

# Записать тестовые данные
sudo bash -c 'for i in $(seq 1 5); do
  dd if=/dev/urandom of=/mnt/raid5/datafile_$i bs=1M count=100 status=none
  echo "Created datafile_$i"
done'
ls -lh /mnt/raid5/
```

---

### 4.4 Симуляция аварии и автоматический rebuild

> **Важно:** дождитесь завершения начальной синхронизации перед тестом аварии.
> Проверьте: `cat /proc/mdstat` — не должно быть строки `resync` или `recovery`.

```bash
# Контрольная сумма перед аварией
md5sum /mnt/raid5/datafile_1 > /tmp/before_checksum.txt

# --- АВАРИЯ ---
sudo mdadm --manage /dev/md0 --fail /dev/sde

# Немедленно проверить — RAID деградирован но работает
cat /proc/mdstat
```

```
md0 : active raid5 sdh[3] sdg[2] sdf[1] sde[0](F)
      [2/3] [_UU]    <- деградированный режим
      [===========>.........]  recovery = 57.2% <- rebuild на sdh уже идёт
```

```bash
# Данные доступны в деградированном режиме!
ls /mnt/raid5/
cat /mnt/raid5/datafile_1 | md5sum

# Следить за rebuild
watch -n 2 cat /proc/mdstat

# После rebuild
sudo mdadm --detail /dev/md0
# State: clean, sdh теперь active sync
```

---

### 4.5 Замена сбойного диска

```bash
sudo mdadm --manage /dev/md0 --remove /dev/sde

# (в реальности здесь физическая замена диска)
sudo wipefs -a /dev/sde
sudo mdadm --manage /dev/md0 --add /dev/sde

sudo mdadm --detail /dev/md0
# sde[4](S) — spare, готов к следующей аварии
```

---

### 4.6 Мониторинг RAID

```bash
# Проверить целостность данных (scrub)
echo check | sudo tee /sys/block/md0/md/sync_action
watch -n 5 cat /proc/mdstat

# По завершению
cat /sys/block/md0/md/mismatch_cnt  # 0 = всё хорошо
```

**Таблица: RAID уровни и их характеристики**

| RAID | Мин. дисков | Отказоустойчивость | Полезный объём | Применение |
|------|-------------|---------------------|----------------|------------|
| RAID 0 | 2 | Нет | 100% | Скорость, не для данных |
| RAID 1 | 2 | 1 диск | 50% | Системные диски |
| RAID 5 | 3 | 1 диск | (N-1)/N | Универсальный |
| RAID 6 | 4 | 2 диска | (N-2)/N | Большие массивы |
| RAID 10 | 4 | 1 из каждой пары | 50% | Базы данных |

**Контрольные вопросы:**
1. Почему RAID — это не резервное копирование?
2. Что произойдёт если выйдут из строя 2 диска в RAID 5 одновременно?
3. Зачем нужен hot spare? Что произойдёт без него при аварии?
4. Сколько полезного места даст RAID 5 из 4 дисков по 10G?
5. Почему перед заменой диска нужно сначала `--remove`?

---

## Модуль 5: Логические тома LVM (связка RAID + LVM)

### Теория для изучения перед модулем

- Архитектура LVM: Physical Volume → Volume Group → Logical Volume
- Physical Extent (PE): единица выделения места в LVM, как влияет на размер томов
- Thin provisioning: выделение места по требованию, переподписка
- LVM snapshot: механизм CoW на уровне блоков, отличие от Btrfs snapshot
- Зачем LVM поверх RAID, а не наоборот: гибкость управления при отказоустойчивом основании
- `pvmove`: онлайн-миграция данных между физическими томами
- `vgscan` / `pvscan` / `vgimport`: восстановление конфигурации LVM после сбоя
- Метаданные LVM: где хранятся, что будет при их потере

---

**Цель:** Создать гибкую инфраструктуру с возможностью изменения размеров томов
«на лету» поверх отказоустойчивого слоя.

**Устройства:** `/dev/md0` (RAID из модуля 4), `sdi` (10G)

---

### 5.1 Инициализация LVM поверх RAID

```bash
# Размонтировать RAID
sudo umount /mnt/raid5

# Дождаться завершения всех операций RAID
sudo mdadm --wait /dev/md0 2>/dev/null; true

# Очистить подпись ext4 оставшуюся от Модуля 4 — иначе pvcreate откажет
sudo wipefs -a /dev/md0

# Создать Physical Volume из RAID-массива
sudo pvcreate /dev/md0

sudo pvs
sudo pvdisplay /dev/md0
```

```bash
# Создать Volume Group
sudo vgcreate infra_vg /dev/md0

sudo vgs
sudo vgdisplay infra_vg
# VG Size: ~20G
```

```bash
# Создать Logical Volume 10G из 20G
# Флаг -y автоматически затирает старые подписи ФС на LV
sudo lvcreate -y -L 10G -n app_lv infra_vg

sudo lvs
sudo lvdisplay /dev/infra_vg/app_lv

sudo vgs
# VFree ~10G — запас для расширения
```

---

### 5.2 Форматирование, монтирование и наполнение данными

```bash
# Форматировать в xfs (-f затирает старые подписи если есть)
sudo mkfs.xfs -f -L app-data /dev/infra_vg/app_lv

sudo mkdir -p /app/data
sudo mount /dev/infra_vg/app_lv /app/data

df -h /app/data
# 10G доступно

# Добавить в fstab
echo "/dev/infra_vg/app_lv  /app/data  xfs  defaults  0  2" | sudo tee -a /etc/fstab

# Наполнить данными
sudo bash -c 'for i in $(seq 1 5); do
  dd if=/dev/urandom of=/app/data/app_data_$i.bin bs=1M count=500 status=none
  echo "Created app_data_$i.bin"
done'

ls -lh /app/data/
df -h /app/data

# Контрольные суммы для проверки целостности после расширения
md5sum /app/data/app_data_1.bin > /tmp/lvm_checksums.txt
```

---

### 5.3 Расширение тома в режиме онлайн

```bash
sudo vgs
# VFree: ~10G

# Расширить LV (том смонтирован, данные доступны!)
sudo lvextend -L +5G /dev/infra_vg/app_lv

# LV вырос, ФС ещё не знает
df -h /app/data   # показывает 10G
sudo lvs          # показывает 15G

# Расширить xfs файловую систему без размонтирования
sudo xfs_growfs /app/data

df -h /app/data
# Теперь ~15G

# Данные целы?
diff <(md5sum /app/data/app_data_1.bin) /tmp/lvm_checksums.txt && echo "OK: данные не повреждены"
```

> **Для ext4:** `sudo resize2fs /dev/infra_vg/app_lv`  
> **xfs уменьшить нельзя** — только увеличивать.

---

### 5.4 Расширение Volume Group новым диском

```bash
sudo vgs
# VFree: ~5G — почти кончается

# Подготовить новый диск
sudo wipefs -a /dev/sdi
sudo pvcreate /dev/sdi
sudo vgextend infra_vg /dev/sdi

sudo vgs
# VFree теперь ~15G

sudo pvs
# /dev/md0   infra_vg  ~20G
# /dev/sdi   infra_vg  ~10G

# Расширить LV на всё свободное место
sudo lvextend -l +100%FREE /dev/infra_vg/app_lv
sudo xfs_growfs /app/data

df -h /app/data
# ~30G доступно

diff <(md5sum /app/data/app_data_1.bin) /tmp/lvm_checksums.txt && echo "OK: данные целы"
```

---

### 5.5 Дополнительные операции LVM

```bash
# Снапшот LV (CoW на уровне блоков)
sudo lvcreate -y -L 2G -s -n app_lv_snap /dev/infra_vg/app_lv

sudo lvs
# app_lv      25G
# app_lv_snap  2G  <- снапшот

# Смонтировать снапшот (только чтение)
sudo mkdir -p /mnt/snap
sudo mount -o ro /dev/infra_vg/app_lv_snap /mnt/snap
ls /mnt/snap/

sudo umount /mnt/snap
sudo lvremove -f /dev/infra_vg/app_lv_snap
```

**Контрольные вопросы:**
1. Почему LVM размещают поверх RAID, а не наоборот?
2. В чём разница между `lvextend -L +5G` и `lvextend -l +100%FREE`?
3. Что такое LVM snapshot и чем он отличается от Btrfs snapshot?
4. Можно ли уменьшить xfs Logical Volume?
5. Что произойдёт если снапшот LV переполнится (закончится выделенные 2G)?

---

## Модуль 6: Troubleshooting — боевые инциденты

### Теория для изучения перед модулем

- Структура inode в Linux: что хранит, чего не хранит (имя файла!)
- Hard link vs Soft link: счётчик ссылок на inode, когда данные реально удаляются
- File descriptor (fd): жизненный цикл, связь с inode, таблица открытых файлов процесса
- Почему `rm` не удаляет данные если файл открыт: счётчик ссылок fd ≠ link count
- `/proc/PID/fd/`: виртуальная директория с дескрипторами процесса
- Инструменты диагностики: `lsof`, `fuser`, `ss`, `strace`
- Разница между `df` (свободное место в ФС) и `du` (фактическое использование файлами)
- Inode exhaustion: почему может кончиться на ext4 но не на xfs

---

**Цель:** Отработка типовых инцидентов, возникающих в production.

---

### Инцидент 1: «No space left on device», хотя `df` показывает свободное место

**Воспроизведение:**

```bash
# Посмотреть стартовое состояние inodes
df -i /data/ext

# Создать сотни тысяч мелких файлов (каждый = 1 inode, но почти 0 места)
sudo bash -c '
mkdir -p /data/ext/inode_test
i=0
while true; do
  touch /data/ext/inode_test/$i 2>/dev/null || {
    echo "INODE EXHAUSTED at $i files"
    break
  }
  i=$((i+1))
done
'
```

**Диагностика:**

```bash
# df -h: места полно!
df -h /data/ext
# /dev/sda1  4.9G  7M  4.6G   1% /data/ext

# df -i: inodes кончились!
df -i /data/ext
# /dev/sda1  327680  327680  0  100% /data/ext

# Сколько inodes задано изначально
sudo tune2fs -l /dev/sda1 | grep -i "inode count"
# Inode count: 327680

# Сравнение с xfs (динамические inodes)
df -i /data/xfs
# xfs никогда не покажет 100% при наличии свободного места
```

**Решение:**

```bash
# Найти директорию с наибольшим числом файлов
sudo find /data/ext -xdev -type d | while read d; do
  echo "$(find "$d" -maxdepth 1 | wc -l) $d"
done | sort -rn | head -10

# Удалить лишние файлы
sudo rm -rf /data/ext/inode_test
df -i /data/ext  # inodes освободились
```

**Профилактика:**

```bash
# При создании ext4 задать больше inodes через bytes-per-inode:
# mkfs.ext4 -i 4096 /dev/sda1   # 1 inode на каждые 4KB
# По умолчанию: 1 inode на 16KB

# На xfs проблема inodes не возникает никогда
```

---

### Инцидент 2: Удалённый файл не освобождает место

**Воспроизведение:**

```bash
# Запустить процесс, который держит файловый дескриптор открытым
# dd открывает файл один раз и пишет непрерывно — fd остаётся открытым
sudo dd if=/dev/urandom of=/data/xfs/big.log bs=1M &
BG_PID=$!
echo "Процесс запущен, PID: $BG_PID"

# Подождать пока файл вырастет
sleep 8
ls -lh /data/xfs/big.log
df -h /data/xfs

# "Удалить" файл
sudo rm /data/xfs/big.log
echo "Файл удалён"
```

```bash
# Файла нет, но место НЕ освободилось!
ls /data/xfs/
df -h /data/xfs   # использование то же!
```

**Диагностика:**

```bash
# Найти процессы удерживающие удалённые fd
sudo lsof +L1
# COMMAND    PID  USER  FD  TYPE DEVICE  SIZE/OFF  NLINK  NODE  NAME
# dd      12345  root  1w   REG   8,18   1G         0    131  /data/xfs/big.log (deleted)
#                                                    ^
#                                           NLINK=0 = удалён, но fd открыт

# Посмотреть fd через /proc
ls -la /proc/${BG_PID}/fd/
# lrwx..  1 -> /data/xfs/big.log (deleted)
```

**Решение:**

```bash
# Вариант 1: завершить процесс (место освободится немедленно)
sudo kill $BG_PID
sleep 1
df -h /data/xfs  # место освободилось!
```

```bash
# Вариант 2: обнулить файл без убийства процесса
# (когда процесс нельзя убить — nginx, java, etc.)
PID=$(sudo lsof +L1 | awk 'NR>1 && /big.log/{print $2}' | head -1)
FD=$(sudo lsof  +L1 | awk 'NR>1 && /big.log/{print $4}' | head -1 | tr -d 'uw')
echo "PID=$PID FD=$FD"

sudo truncate -s 0 /proc/$PID/fd/$FD
df -h /data/xfs  # место освободилось, процесс продолжает работать!
sudo kill $PID 2>/dev/null
```

---

### Бонус: Общая диагностика дисковых проблем

```bash
# Ошибки дисков в журнале ядра
sudo dmesg | grep -E "error|I/O error|failed" | tail -20

# Самые большие файлы
sudo find /data -type f -exec du -sh {} + 2>/dev/null | sort -rh | head -20

# Самые большие директории
sudo du -sh /data/* | sort -rh | head -10

# Поиск inode-бомб (директорий с огромным числом файлов)
sudo find /data -xdev -type d -exec sh -c \
  'echo "$(ls -1 "$1" | wc -l) $1"' _ {} \; | sort -rn | head -10

# Все открытые файлы на конкретном разделе
sudo lsof /data/xfs
```

**Контрольные вопросы:**
1. Почему `rm` не освобождает место если файл открыт процессом?
2. Как можно очистить содержимое файла не убивая процесс?
3. Как настроить мониторинг на исчерпание inodes (а не только места)?
4. Что такое `NLINK=0` в выводе `lsof +L1`?
5. Команда `lsof +L1` — что означает `+L1`?

---

## Финальная карта использования дисков

| Диск | Модуль | Что сделано |
|------|--------|-------------|
| sda | 2 | GPT → sda1 (ext4, `/data/ext`) + sda2 (xfs, `/data/xfs`) |
| sdb, sdc | 3 | Btrfs RAID 1, субтомы `@data`/`@logs`, снапшоты |
| sde, sdf, sdg | 4 | RAID 5 (`/dev/md0`) |
| sdh | 4 | Hot spare → после rebuild: active sync |
| /dev/md0 | 5 | LVM PV → `infra_vg` → `app_lv` (xfs, `/app/data`) |
| sdi | 5 | `vgextend infra_vg` |
| sdd | — | Сравнение tmpfs vs диск (модуль 1), системный диск на mount |

---

## Теоретические вопросы (итоговые)

### Блок 1: Файловые системы и ядро

1. Что такое VFS (Virtual File System) и зачем она нужна в Linux? Какие ФС реализуют интерфейс VFS?
2. Чем отличается `tmpfs` от `ramfs`? Почему `ramfs` опасен в production?
3. Что произойдёт с процессом, если ОС исчерпает все доступные inodes? Получит ли он ошибку сразу или позже?
4. Объясните разницу между hard link и symbolic link с точки зрения структуры inode и счётчика ссылок.
5. Что такое журнал (journal) в ФС? Какие три режима журналирования есть в ext4 и чем они отличаются?
6. Почему на ext4 inodes могут кончиться раньше дискового пространства, а на xfs — нет?

### Блок 2: Разделы и монтирование

7. В чём фундаментальное отличие MBR от GPT? Почему GPT является стандартом для дисков >2TB?
8. Что означает `noatime` в опциях монтирования? На каких рабочих нагрузках это даёт заметный прирост?
9. Почему в `/etc/fstab` рекомендуется использовать UUID, а не `/dev/sda1`? Назовите сценарий когда `/dev/sda1` изменится без физической замены диска.
10. Что произойдёт при загрузке сервера если в `/etc/fstab` указан несуществующий UUID? Как это исправить?
11. Каков смысл последних двух полей в строке fstab? Что означает значение `2` в поле pass?

### Блок 3: Btrfs и CoW

12. Объясните принцип Copy-on-Write. Почему снапшот в CoW-системе при создании занимает ~0 байт?
13. Чем встроенный RAID в Btrfs принципиально отличается от mdadm RAID? Назовите преимущества и недостатки каждого подхода.
14. Почему Btrfs RAID 5/6 считается ненадёжным и не рекомендуется для production?
15. Что такое subvolume в Btrfs? Чем он отличается от обычной директории? Можно ли применить квоту к директории?

### Блок 4: RAID

16. Как вычисляется полезный объём RAID 5 из N дисков? Почему RAID 5 из 3 дисков по 10G даёт 20G, а не 30G?
17. Что такое «деградированный режим» RAID 5? Как меняется производительность и доступность данных?
18. Чем RAID 10 лучше RAID 5 для баз данных, несмотря на меньший полезный объём?
19. Что произойдёт с данными если во время rebuild RAID 5 выйдет из строя ещё один диск?
20. Зачем нужен hot spare? Как он влияет на MTTDL (Mean Time To Data Loss)?

### Блок 5: LVM

21. Опишите трёхуровневую архитектуру LVM: Physical Volume → Volume Group → Logical Volume. Что такое Physical Extent?
22. Почему LVM размещают поверх RAID, а не наоборот? Что будет если сделать наоборот?
23. Чем LVM snapshot отличается от Btrfs snapshot? Почему LVM snapshot деградирует со временем?
24. Что произойдёт с данными если LVM snapshot переполнится (исчерпает выделенное ему пространство)?
25. Как безопасно вывести Physical Volume из Volume Group? Что нужно сделать до `vgreduce`?

### Блок 6: Troubleshooting

26. Процесс записывает данные в файл. Администратор удаляет файл через `rm`. Опишите шаг за шагом что происходит на уровне inode, dentry и файлового дескриптора.
27. Команда `df -h` показывает 0% использования, но `du -sh /*` даёт сумму больше чем размер диска. Как такое возможно?
28. Вы видите в `dmesg` сообщения `EXT4-fs error (device sda1): ext4_find_entry`. О чём это говорит и каков план действий?
29. После добавления строки в `/etc/fstab` сервер не загрузился. Как восстановить доступ не имея физического доступа к машине? (Контекст: облачный сервер GCP.)
30. На сервере `df -h` показывает 100% на `/`. `du -sh /*` не объясняет куда делось место. Назовите как минимум три причины такого расхождения и как диагностировать каждую.

---

## Шпаргалка

```bash
# === Просмотр ===
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID
sudo parted /dev/sdX print
sudo blkid
df -h && df -i              # место + inodes
sudo du -sh /path/*

# === Разделы ===
sudo parted /dev/sdX --script mklabel gpt mkpart primary 1MiB 5GiB mkpart primary 5GiB 100%
sudo partprobe /dev/sdX
sudo mkfs.ext4 -L label /dev/sdX1
sudo mkfs.xfs -L label /dev/sdX2
sudo mkfs.btrfs -m raid1 -d raid1 /dev/sdX /dev/sdY

# === Монтирование ===
sudo mount /dev/sdX1 /mnt/point
sudo umount /mnt/point
sudo mount -a               # применить fstab

# === LVM ===
sudo pvs / vgs / lvs
sudo pvcreate /dev/sdX
sudo vgcreate vg_name /dev/sdX
sudo lvcreate -y -L 10G -n lv_name vg_name
sudo lvextend -L +5G /dev/vg/lv && sudo resize2fs /dev/vg/lv        # ext4
sudo lvextend -l +100%FREE /dev/vg/lv && sudo xfs_growfs /mountpoint # xfs

# === RAID ===
cat /proc/mdstat
sudo mdadm --detail /dev/md0
sudo mdadm --wait /dev/md0
sudo mdadm --manage /dev/md0 --fail /dev/sdX
sudo mdadm --manage /dev/md0 --remove /dev/sdX
sudo mdadm --manage /dev/md0 --add /dev/sdX

# === Btrfs ===
sudo btrfs filesystem show /mnt/point
sudo btrfs subvolume list /mnt/point
sudo btrfs subvolume create /mnt/point/@name
sudo btrfs subvolume snapshot -r /mnt/point/@data /mnt/point/@snap
sudo btrfs subvolume delete /mnt/point/@snap

# === Troubleshooting ===
sudo lsof +L1                                       # удалены но открыты
sudo lsof | grep deleted
PID=$(sudo lsof +L1 | awk 'NR>1 && /file/{print $2}' | head -1)
FD=$(sudo lsof  +L1 | awk 'NR>1 && /file/{print $4}' | head -1 | tr -d 'uw')
sudo truncate -s 0 /proc/$PID/fd/$FD               # обнулить без kill
df -i /path                                         # проверить inodes
sudo tune2fs -l /dev/sdX1                           # параметры ext4
sudo dmesg | grep -i error                          # ошибки дисков в ядре
```
