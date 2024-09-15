
# Лабораторная работа: Управление CPU с использованием cgroup v2 в Linux

# База (узел 2 ядра 4 ГБ)

1. Обновите систему и установите необходимые пакеты:
    ```bash
    sudo apt update
    sudo apt install stress cgroup-tools htop
    ```

2. Проверьте доступные подсистемы cgroups:
    ```bash
    lssubsys -am
    ```

    Вы должны увидеть подсистему `cpu` в списке.

3. Проверьте, смонтирована ли система cgroups версии 2:
    ```bash
    mount | grep cgroup
    ```

    Вы должны увидеть монтированную файловую систему `cgroup2`.

## Шаг 1: Создание cgroup для ограничения CPU

1. Создайте новую cgroup для управления использованием CPU:
    ```bash
    sudo mkdir /sys/fs/cgroup/limited_cpu_group
    ```

2. Установите ограничение на использование процессорного времени. В данном примере процессам внутри группы будет доступно до 50 мс CPU времени на каждые 100 мс (что эквивалентно 50% CPU, файл принимает значения в микросекундах):
    ```bash
    echo "50000 100000" | sudo tee /sys/fs/cgroup/limited_cpu_group/cpu.max
    ```

## Шаг 2: Запуск нагрузки

1. Запустите процесс, который создаст нагрузку на CPU:
    ```bash
    stress --cpu 2 --timeout 240 &
    ```

2. Найдите PID запущенного процесса `stress`:
    ```bash
    ps aux | grep stress
    ```

    Скопируйте PID процесса из вывода команды.

## Шаг 3: Добавление процесса в cgroup

1. Добавьте PID процесса в созданную cgroup:
    ```bash
    echo <PID1> | sudo tee /sys/fs/cgroup/limited_cpu_group/cgroup.procs
    ```

    При необходимости добавьте и другие процессы, если их несколько:
    ```bash
    echo <PIDN> | sudo tee /sys/fs/cgroup/limited_cpu_group/cgroup.procs
    ```

## Шаг 4: Проверка работы

1. Используйте команду `htop` для наблюдения за тем, как процесс использует CPU:
    ```bash
    top
    ```

2. Проверьте, что процесс находится в нужной группе cgroups, выполнив:
    ```bash
    cat /sys/fs/cgroup/limited_cpu_group/cgroup.procs
    ```

## Шаг 5: Очищение

1. После завершения работы можно удалить созданную cgroup:
    ```bash
    sudo rmdir /sys/fs/cgroup/limited_cpu_group
    ```
