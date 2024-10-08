
# Лабораторная работа: Ограничение скорости записи на диск с использованием cgroups

## База

1. Установите необходимые пакеты:
    ```bash
    sudo apt update
    sudo apt install cgroup-tools sysstat htop
    ```

2. Проверьте, что система использует cgroup версии 2:
    ```bash
    mount | grep cgroup2
    ```

## Шаг 1: Определение идентификатора диска

1. Выполните команду `lsblk`, чтобы узнать идентификатор вашего диска:
    ```bash
    lsblk
    ```
    Например, для диска `/dev/sda` идентификатором может быть `8:0`.

## Шаг 2: Настройка ограничения скорости записи на диск с использованием cgroups

1. Создайте новую группу cgroup для ограничения скорости записи:
    ```bash
    sudo mkdir /sys/fs/cgroup/io_limit_group
    ```
    
Добавьте подсистему io.max если она не присутвует

    ```bash
    echo "+io" | sudo tee /sys/fs/cgroup/cgroup.subtree_control
    ```

2. Установите ограничение на запись для диска. Например, для диска `sda` с идентификатором `8:0` ограничим запись до 1 MB/с:
    ```bash
    echo "8:0 wbps=1048576" | sudo tee /sys/fs/cgroup/io_limit_group/
    ```

3. Проверьте, что ограничение было установлено:
    ```bash
    cat /sys/fs/cgroup/io_limit_group/io.max
    ```

## Шаг 3: Запуск процесса записи на диск

1. Запустите процесс записи на диск с использованием `dd`, который создаст файл размером 5 GB:
    ```bash
    dd if=/dev/zero of=/tmp/testfile bs=1M count=5000 oflag=direct &
    ```

2. Найдите PID запущенного процесса `dd` или просто возмите его из скобочек []:
    ```bash
    ps aux | grep dd
    ```

3. Добавьте процесс в созданную группу cgroup:
    ```bash
    echo <PID> | sudo tee /sys/fs/cgroup/io_limit_group/cgroup.procs
    ```
    Замените `<PID>` на фактический идентификатор процесса.

## Шаг 4: Проверка результата

1. Используйте `iostat` или `htop` для мониторинга производительности диска:
    ```bash
    iostat -dx 2
    ```

    Следите за скоростью записи, она должна быть ограничена до 1 MB/с.

## Шаг 5: Запуск процесса с использованием `systemd-run`

1. Вы можете запустить процесс записи на диск с ограничением скорости записи напрямую через `systemd-run`:
    ```bash
    sudo systemd-run --scope -p "IOWriteBandwidthMax=/dev/sda 1M" dd if=/dev/zero of=/tmp/testfile bs=1M count=100 oflag=direct
    ```
    Эта команда сразу запускает процесс с ограничением записи до 1 MB/с.

## Шаг 6: Очистка

1. После завершения работы удалите созданную cgroup:
    ```bash
    sudo rmdir /sys/fs/cgroup/io_limit_group
    ```

2. Удалите тестовый файл:
    ```bash
    sudo rm /tmp/testfile
    ```
