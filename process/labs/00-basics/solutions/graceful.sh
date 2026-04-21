#!/bin/bash
# Решение задания 4: скрипт с обработчиком SIGTERM
#
# Перехватывает SIGTERM → удаляет lock и выходит.
# При SIGKILL — умирает моментально, lock остаётся (демонстрация разницы).

trap 'echo "получил SIGTERM, прибираюсь..."; rm -f /tmp/mylock; exit 0' TERM

touch /tmp/mylock
echo "PID=$$, lock создан: /tmp/mylock"

while true; do
  sleep 1
done
