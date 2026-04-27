#!/usr/bin/env bash
# Автотест 05: bind на :80 от nobody работает только с CAP_NET_BIND_SERVICE.
# Используем фиксированную выжидательную логику: ждём пока порт реально
# зашуршит в ss, до 3 секунд.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require setcap getcap python3 ss

PYWEB=/tmp/pyweb-check
trap 'pkill -f "$PYWEB" 2>/dev/null; rm -f "$PYWEB"' EXIT

cp "$(command -v python3)" "$PYWEB"
chmod 0755 "$PYWEB"

# 80 порт должен быть свободен
if ss -tln '( sport = :80 )' 2>/dev/null | grep -q ":80"; then
  echo "Порт 80 уже занят — пропускаем тест" >&2
  exit 0
fi

# Хелпер: запустить от nobody, подождать до N секунд пока порт займётся
start_and_check_port() {
  local port="$1"
  pkill -f "$PYWEB" 2>/dev/null; sleep 0.2
  su -s /bin/bash nobody -c "exec $PYWEB -m http.server $port --bind 127.0.0.1" >/dev/null 2>&1 &
  local pid=$!
  for _ in $(seq 1 20); do
    if ss -tln "( sport = :$port )" 2>/dev/null | grep -q ":$port"; then
      kill $pid 2>/dev/null; wait 2>/dev/null
      return 0
    fi
    if ! kill -0 $pid 2>/dev/null; then
      # процесс умер не дождавшись порта
      return 1
    fi
    sleep 0.15
  done
  kill $pid 2>/dev/null; wait 2>/dev/null
  return 1
}

log "БЕЗ capability — bind на :80 от nobody должен УПАСТЬ"
assert_fail "nobody слушает :80 без CAP_NET_BIND_SERVICE" \
  start_and_check_port 80

log "С CAP_NET_BIND_SERVICE — bind на :80 РАБОТАЕТ"
setcap cap_net_bind_service+ep "$PYWEB"
note "getcap: $(getcap "$PYWEB")"
assert "nobody слушает :80 ПОСЛЕ setcap" \
  start_and_check_port 80

log "после setcap -r снова не работает"
setcap -r "$PYWEB"
assert_fail "nobody снова не может слушать :80 после setcap -r" \
  start_and_check_port 80

# Sanity-check: на 8080 (>1024) должно работать всегда без cap
log "санити-чек: nobody на :8080 без cap — работает (порт >1024)"
assert "nobody слушает :8080 (непривилегированный порт)" \
  start_and_check_port 8080

summary
