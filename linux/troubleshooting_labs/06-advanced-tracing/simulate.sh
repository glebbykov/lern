#!/usr/bin/env bash
echo "Запускаем 'зависшее' приложение..."

cat << 'APP' > /tmp/stuck_app.py
import time
import sys

print("Приложение запущено. Жду конфиг...")
while True:
    try:
        with open("/tmp/missing_config.conf", "r") as f:
            print("Конфиг найден! Успешное завершение.")
            sys.exit(0)
    except FileNotFoundError:
        pass
    time.sleep(1)
APP

python3 /tmp/stuck_app.py >/dev/null 2>&1 &
PID=$!
echo "Приложение (PID $PID) крутится в фоне."
echo "Оно ждет какой-то файл, но в логах пусто."
echo "Используй strace -p $PID, чтобы узнать, какой файл ему нужен, и создай его!"
