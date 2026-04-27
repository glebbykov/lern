#!/usr/bin/env bash
echo "Создаем 'утечку' дискового пространства..."
# Создаем большой файл
dd if=/dev/urandom of=/tmp/hidden_leak.dat bs=1M count=500 status=none
# Открываем его на чтение в фоновом процессе (tail -f)
tail -f /tmp/hidden_leak.dat &>/dev/null &
PID=$!
# Удаляем файл из файловой системы!
rm -f /tmp/hidden_leak.dat
echo "Файл удален, но место не освободилось! Найди процесс, который его держит (PID скрыт)."
