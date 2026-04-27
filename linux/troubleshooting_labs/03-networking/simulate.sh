#!/usr/bin/env bash
echo "Запускаем веб-сервер на порту 8888..."
python3 -m http.server 8888 &>/dev/null &
PID=$!
echo "Имитируем 'проблему с сетью' (блокируем порт 8888 в iptables)..."
iptables -A INPUT -p tcp --dport 8888 -j DROP
echo "Сервер запущен (PID $PID), но curl http://127.0.0.1:8888 зависает. Почини!"
