#!/bin/bash
# Простой сервис для задания 5 — пишет время каждые 5 секунд.
# Отправляется в journald через systemd.

while true; do
  echo "[$(date '+%H:%M:%S')] Привет от hello.service, PID=$$"
  sleep 5
done
