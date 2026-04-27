#!/usr/bin/env bash
# Автотест 07: профиль реально блокирует /etc/passwd, разрешает /tmp.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require apparmor_parser

if ! [[ -d /sys/kernel/security/apparmor ]]; then
  printf '%sAppArmor не активен в ядре — этап пропускаем (это OK для WSL/контейнеров)%s\n' \
    "${C_YELLOW}" "${C_RESET}"
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

install -m 0755 "$(dirname "$0")/secret-reader.sh" "$SCRIPT"
cp "$PROFILE_SRC" "$PROFILE_DST"
apparmor_parser -r "$PROFILE_DST"

OUT=$("$SCRIPT" 2>&1)
note "вывод скрипта под профилем:"
echo "$OUT" | sed 's/^/   /'

assert "под профилем чтение /etc/passwd ЗАБЛОКИРОВАНО" \
  bash -c 'grep -q "READ_PASSWD: DENIED" <<< "'"$OUT"'"'

assert "под профилем запись в /var/log ЗАБЛОКИРОВАНА" \
  bash -c 'grep -q "WRITE_VARLOG: DENIED" <<< "'"$OUT"'"'

assert "под профилем запись в /tmp РАЗРЕШЕНА" \
  bash -c 'grep -q "WRITE_TMP: OK" <<< "'"$OUT"'"'

# проверяем что профиль реально загружен
assert "профиль виден в /sys/kernel/security/apparmor/profiles" \
  bash -c 'grep -q secret-reader /sys/kernel/security/apparmor/profiles'

summary
