#!/bin/bash
# ──────────────────────────────────────────────────────────────────
# diskmon.sh — мониторинг использования диска (задание 8)
#
# Использование: скопировать в /opt/diskmon.sh
#   sudo cp solutions/diskmon.sh /opt/diskmon.sh
#   sudo chmod +x /opt/diskmon.sh
# ──────────────────────────────────────────────────────────────────

trap 'echo "[diskmon] Shutting down (SIGTERM)..."; exit 0' TERM

echo "[diskmon] Started. PID=$$"

while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $(df -h / | tail -1)"
    sleep 30
done
