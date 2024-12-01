
# Работа с дисками (mount/umount) и LVM (Logical Volume Manager)

## Основы LVM
**Logical Volume Manager (LVM)** — это система управления дисковым пространством, которая позволяет:
- Объединять несколько физических носителей в одну группу (VG), что обеспечивает масштабирование дискового пространства.
- Добавлять диски в существующую группу томов.
- Создавать снапшоты для тестирования, отката и резервного копирования.

Снапшоты являются инкрементальными, то есть содержат только изменения по сравнению с исходным состоянием. Это позволяет экономить место.

### Компоненты LVM:
1. **Physical Volume (PV)** — физический том. Это первый уровень абстракции. Диск становится PV с помощью команды:
   ```bash
   pvcreate /dev/sdX
   ```
   Просмотреть физические тома:
   ```bash
   pvdisplay
   ```
2. **Volume Group (VG)** — группа томов, которая объединяет несколько PV. Создать VG:
   ```bash
   vgcreate my_vg /dev/sdX /dev/sdY
   ```
   Просмотреть группы томов:
   ```bash
   vgdisplay
   ```
3. **Logical Volume (LV)** — логический том, который создаётся в VG. Создать LV:
   ```bash
   lvcreate -L 10G -n my_lv my_vg
   ```
   Просмотреть логические тома:
   ```bash
   lvdisplay
   ```

### Шаги настройки LVM:
1. Инициализируем диски как PV:
   ```bash
   pvcreate /dev/sdX
   ```
2. Создаём VG:
   ```bash
   vgcreate my_vg /dev/sdX /dev/sdY
   ```
3. Создаём логический том:
   ```bash
   lvcreate -L 10G -n my_lv my_vg
   ```
4. Форматируем LV:
   ```bash
   mkfs.ext4 /dev/my_vg/my_lv
   ```
5. Создаём точку монтирования:
   ```bash
   mkdir /mnt/volume1
   ```
6. Монтируем LV:
   ```bash
   mount /dev/my_vg/my_lv /mnt/volume1
   ```
7. Добавляем запись в `/etc/fstab` для автоподключения:
   ```
   /dev/my_vg/my_lv /mnt/volume1 ext4 defaults 0 2
   ```

### Увеличение и уменьшение размера томов:
- Увеличение LV:
  ```bash
  lvextend -L +5G /dev/my_vg/my_lv
  resize2fs /dev/my_vg/my_lv
  ```
- Уменьшение LV:
  ```bash
  e2fsck -f /dev/my_vg/my_lv
  lvreduce -L 1G /dev/my_vg/my_lv
  ```

### Удаление томов:
- Удаление LV:
  ```bash
  lvremove /dev/my_vg/my_lv
  ```
- Удаление VG:
  ```bash
  vgremove my_vg
  ```
- Удаление PV:
  ```bash
  pvremove /dev/sdX
  ```

## Работа с файлами подкачки (Swap):
1. Выделяем место:
   ```bash
   fallocate -l 1G /swapfile
   ```
2. Устанавливаем права:
   ```bash
   chmod 600 /swapfile
   ```
3. Инициализируем файл подкачки:
   ```bash
   mkswap /swapfile
   ```
4. Активируем swap:
   ```bash
   swapon /swapfile
   ```
5. Для отключения:
   ```bash
   swapoff /swapfile
   ```

## Работа с дисками через `fdisk`:
1. Открываем диск:
   ```bash
   fdisk /dev/sdb
   ```
2. Создаём новый раздел:
   - Выбираем `n` (new partition).
   - Сохраняем изменения командой `w`.
3. Форматируем раздел:
   ```bash
   mkfs.ext4 /dev/sdb1
   ```
4. Создаём точку монтирования:
   ```bash
   mkdir /mnt/sdb
   ```
5. Монтируем диск:
   ```bash
   mount /dev/sdb1 /mnt/sdb
   ```
6. Добавляем в `/etc/fstab` для автоподключения:
   ```
   UUID=<uuid-диска> /mnt/sdb ext4 defaults 0 2
   ```
7. Обновляем таблицу разделов:
   ```bash
   partprobe /dev/sdb
   ```

## Команды для диагностики:
- Просмотр информации о дисках:
  ```bash
  lsblk
  ```
- Просмотр файловых систем:
  ```bash
  blkid
  ```
- Проверка и исправление ошибок файловой системы:
  ```bash
  e2fsck -f /dev/sdb1
  ```

## Создание снапшотов:
Снапшоты позволяют создавать копии состояния дисков:
```bash
lvcreate --snapshot --size 1G --name snap_my_lv /dev/my_vg/my_lv
```
Удаление снапшота:
```bash
lvremove /dev/my_vg/snap_my_lv
```

## Использование нагрузки с `stress`:
Команда `stress` создаёт нагрузку на ресурсы системы:
```bash
stress --vm 1 --vm-bytes 4G --timeout 60
```
- `--vm 1` — создаёт 1 виртуальный процесс.
- `--vm-bytes 4G` — использует 4 ГБ памяти.
- `--timeout 60` — продолжительность нагрузки 60 секунд.
