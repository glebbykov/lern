#!/usr/bin/env bash
echo "Запускаем генератор 'подозрительного' HTTP-трафика в фоне..."

bash -c 'while true; do curl -s --connect-timeout 1 http://93.184.216.34 > /dev/null 2>&1; sleep 2; done' &
PID=$!

echo "Генератор работает (PID $PID скрыт)."
echo "Используй tcpdump port 80 -n, чтобы узнать, на какой внешний IP-адрес идут запросы!"
