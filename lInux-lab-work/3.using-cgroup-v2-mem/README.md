
# Лабораторная работа: Ограничение использования оперативной памяти с использованием cgroups

## База

1. Установите необходимые утилиты:
    ```bash
    sudo apt update
    sudo apt install stress cgroup-tools
    ```

2. Проверьте, что система использует cgroup версии 2:
    ```bash
    mount | grep cgroup2
    ```

## Шаг 1: Создание группы cgroup для ограничения памяти

1. Создайте новую группу cgroup для ограничения использования оперативной памяти:
    ```bash
    sudo mkdir /sys/fs/cgroup/memory_limit_group
    ```

2. Установите лимит на использование оперативной памяти. Например, установим лимит в 500 MB:
    ```bash
    echo "500M" | sudo tee /sys/fs/cgroup/memory_limit_group/memory.max
    ```

3. Проверьте, что лимит был установлен:
    ```bash
    cat /sys/fs/cgroup/memory_limit_group/memory.max
    ```

## Шаг 2: Запуск процесса с помощью `stress`

1. Запустите процесс с помощью утилиты `stress`, который создаст нагрузку на оперативную память (например, выделит 1 GB памяти):
    ```bash
    stress --vm 1 --vm-bytes 1G --timeout 60 &
    ```

2. Найдите PID запущенного процесса:
    ```bash
    ps aux | grep stress
    ```

3. Добавьте процесс в созданную группу cgroup, чтобы ограничить его использование памяти:
    ```bash
    echo <PID> | sudo tee /sys/fs/cgroup/memory_limit_group/cgroup.procs
    ```
    Замените `<PID>` на фактический PID процесса.

4. Если необходимо завершить процесс, используйте команду `kill`:
    ```bash
    kill <PID>
    ```

## Шаг 3: Изменение лимита и повторный тест

1. Установите новый лимит для использования оперативной памяти, например, 200 MB:
    ```bash
    echo "200M" | sudo tee /sys/fs/cgroup/memory_limit_group/memory.max
    ```

2. Запустите процесс, который попытается использовать больше памяти (например, 3 GB):
    ```bash
    stress --vm 1 --vm-bytes 3G --timeout 120 &
    ```

3. Найдите PID процесса и добавьте его в cgroup:
    ```bash
    echo <PID> | sudo tee /sys/fs/cgroup/memory_limit_group/cgroup.procs
    ```

4. Если процесс превышает лимит по памяти, система может его завершить.

## Шаг 4: Очистка

1. После завершения работы удалите созданную группу cgroup:
    ```bash
    sudo rmdir /sys/fs/cgroup/memory_limit_group
    ```

