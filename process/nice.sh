#!/bin/bash

perform_task() {
    local name=$1
    local count=$2
    local start_time=$(date +%s)

    echo "Запуск $name..."
    sum=0
    for i in $(seq 1 $count); do
        sum=$((sum + i))
    done
    local end_time=$(date +%s)

    echo "$name завершен. Время выполнения: $((end_time - start_time)) секунд."
}

nice -n 10 bash -c "$(declare -f perform_task); perform_task 'Процесс с низким  приоритетом ' 4000000" &

# nice -n -10 (отрицательный приоритет) требует root / CAP_SYS_NICE.
# Запусти через sudo, иначе получишь "Permission denied":
#   sudo nice -n -10 bash -c "..."
# Для обычного пользователя максимум — nice -n 0 (без повышения).
sudo nice -n -10 bash -c "$(declare -f perform_task); perform_task 'Процесс с высоким приоритетом' 4000000" &

wait
echo "Все процессы завершены."
