#!/usr/bin/env bash
# Этап 07: загружаем AppArmor профиль и наблюдаем как он блокирует
# чтение /etc/passwd даже из-под root.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require apparmor_parser aa-status

# Проверяем, что AppArmor реально работает
if ! [[ -d /sys/kernel/security/apparmor ]]; then
  echo "AppArmor недоступен в ядре. Этап пропускаем (WSL/Docker?)" >&2
  exit 0
fi

SCRIPT=/usr/local/bin/secret-reader.sh
PROFILE_SRC="$(dirname "$0")/profile.aa"
PROFILE_DST=/etc/apparmor.d/usr.local.bin.secret-reader.sh

cleanup() {
  apparmor_parser -R "$PROFILE_DST" 2>/dev/null || true
  rm -f "$PROFILE_DST" "$SCRIPT"
}
trap cleanup EXIT

log "1) ставим тестовый скрипт в /usr/local/bin"
install -m 0755 "$(dirname "$0")/secret-reader.sh" "$SCRIPT"

log "2) запуск БЕЗ профиля — всё разрешено (uid 0)"
"$SCRIPT" | sed 's/^/  /'

log "3) загружаем AppArmor профиль (enforce)"
cp "$PROFILE_SRC" "$PROFILE_DST"
apparmor_parser -r "$PROFILE_DST"
note "профиль загружен в ядро"

log "4) запуск С профилем — /etc/passwd и /var/log заблокированы"
"$SCRIPT" | sed 's/^/  /' || true

log "5) aa-status — наш профиль виден"
aa-status 2>/dev/null | grep -E '(secret-reader|enforced|complain)' | head -5 | sed 's/^/  /'

log "6) переводим в complain — нарушения только логируются"
aa-complain "$SCRIPT" 2>/dev/null || true
"$SCRIPT" | sed 's/^/  /' || true

log "7) проверяем dmesg на DENIED записи"
dmesg | grep -i 'apparmor.*DENIED.*secret-reader' | tail -3 | sed 's/^/  /' || \
  echo "  записей нет (нужен sudo dmesg, может быть kptr_restrict)"
