#!/usr/bin/env bash
# Этап 05: даём программе ровно одну привилегию из root и смотрим эффект.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require setcap getcap capsh python3

PYWEB=/tmp/pyweb
log "копируем python3 в $PYWEB чтобы не трогать системный"
cp "$(command -v python3)" "$PYWEB"

log "1) от nobody на 8080 (нужен любой свободный порт >1024) — должно сработать"
timeout 1 su -s /bin/bash nobody -c "$PYWEB -m http.server 8080 --bind 127.0.0.1" >/dev/null 2>&1 &
SERVER_PID=$!
sleep 0.5
curl -sS -o /dev/null -w "  http://127.0.0.1:8080 → %{http_code}\n" http://127.0.0.1:8080 || true
kill $SERVER_PID 2>/dev/null || true; wait 2>/dev/null || true

log "2) от nobody на 80 (привилегированный) БЕЗ capability — Permission denied"
su -s /bin/bash nobody -c "$PYWEB -m http.server 80 --bind 127.0.0.1" 2>&1 | head -3 || true

log "3) выдаём CAP_NET_BIND_SERVICE на $PYWEB"
setcap cap_net_bind_service+ep "$PYWEB"
note "getcap → $(getcap "$PYWEB")"

log "4) от nobody на 80 С capability — теперь работает"
timeout 1 su -s /bin/bash nobody -c "$PYWEB -m http.server 80 --bind 127.0.0.1" >/dev/null 2>&1 &
SERVER_PID=$!
sleep 0.5
curl -sS -o /dev/null -w "  http://127.0.0.1:80 → %{http_code}\n" http://127.0.0.1:80 || true
kill $SERVER_PID 2>/dev/null || true; wait 2>/dev/null || true

log "5) capsh --print текущей оболочки (родительская — root, все 40+ caps)"
capsh --print | head -8

log "6) запускаем sh с дропнутыми ВСЕМИ caps кроме CHOWN"
note "ниже команда chown сработает, mount — нет"
capsh --keep=1 --user=nobody --inh=cap_chown --addamb=cap_chown -- -c '
  echo "  uid=$(id -u)  cap=$(grep CapEff /proc/self/status)"
  touch /tmp/cap-demo && chown root:root /tmp/cap-demo && echo "  chown OK" || echo "  chown FAIL"
  mount -t tmpfs none /mnt 2>&1 | head -1 || true
' 2>&1 | head -10

log "приборка"
setcap -r "$PYWEB" 2>/dev/null || true
rm -f "$PYWEB" /tmp/cap-demo
