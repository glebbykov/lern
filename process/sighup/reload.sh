#!/bin/bash

# Путь к конфигурационному файлу
CONFIG_FILE="./config.txt"

# Функция для чтения конфигурации
read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "[$(date)] Конфигурация загружена: PARAM1=$PARAM1, PARAM2=$PARAM2"
    else
        echo "[$(date)] Конфигурационный файл не найден."
    fi
}

# Обработчик сигнала SIGHUP
reload_config() {
    echo "[$(date)] Получен сигнал SIGHUP. Перечитываем конфигурацию..."
    read_config
}

# Задание начальной конфигурации
PARAM1="default1"
PARAM2="default2"

# Чтение начальной конфигурации
read_config

# Захват сигнала SIGHUP и привязка к обработчику
trap 'reload_config' SIGHUP

# Основной цикл
while true; do
    echo "[$(date)] Рабочий процесс. PARAM1=$PARAM1, PARAM2=$PARAM2"
    sleep 10
done
