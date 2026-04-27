#!/usr/bin/env bash

# Опускаем дефолтный лимит ядра временно (чтобы сымитировать слабую машину)
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    sysctl -w fs.inotify.max_user_watches=8192 >/dev/null 2>&1 || true
fi

echo "Создаем 15000 тестовых файлов в /tmp/inotify_test..."
mkdir -p /tmp/inotify_test
rm -rf /tmp/inotify_test/*

# Быстро создаем файлы
seq 1 15000 | xargs -I{} -P 10 touch /tmp/inotify_test/file_{}

echo "Попытка подписаться на изменения 15000 файлов через inotify..."

# Пишем простенький python-скрипт, который использует inotify
cat << 'PYTHON' > /tmp/test_inotify.py
import os
import sys

try:
    import pyinotify
except ImportError:
    print("Установка модуля pyinotify...")
    os.system("pip3 install pyinotify >/dev/null 2>&1")
    import pyinotify

wm = pyinotify.WatchManager()
mask = pyinotify.IN_MODIFY
directory = "/tmp/inotify_test"

count = 0
try:
    for filename in os.listdir(directory):
        filepath = os.path.join(directory, filename)
        if os.path.isfile(filepath):
            wm.add_watch(filepath, mask)
            count += 1
    print(f"УСПЕХ! Удалось подписаться на {count} файлов.")
    sys.exit(0)
except pyinotify.WatchManagerError as err:
    print(f"ОШИБКА: {err}")
    print("Не удалось подписаться на все файлы! Возможно, исчерпан лимит fs.inotify.max_user_watches.")
    sys.exit(1)
PYTHON

python3 /tmp/test_inotify.py
EXIT_CODE=$?

rm -rf /tmp/inotify_test /tmp/test_inotify.py

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "\n✅ Отличная работа! Ядро настроено правильно."
else
    echo -e "\n❌ Тест провален. Увеличь лимит ядра через sysctl!"
fi
