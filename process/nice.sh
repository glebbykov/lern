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

nice -n 10 bash -c "$(declare -f perform_task); perform_task 'Процесс с низким  приоритетом ' 9000000" &

nice -n -10 bash -c "$(declare -f perform_task); perform_task 'Процесс с высоким приоритетом' 9000000" &

wait
echo "Все процессы завершены."
