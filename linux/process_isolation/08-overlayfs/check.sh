#!/usr/bin/env bash
# Автотест 08: проверяем CoW и whiteout как факты в файловой системе.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"

BASE=/lab/08-check
trap 'umount "$BASE/merged" 2>/dev/null; rm -rf "$BASE"' EXIT

rm -rf "$BASE"
mkdir -p "$BASE"/{lower,upper,work,merged}

ORIG="original content"
echo "$ORIG" > "$BASE/lower/file.txt"
echo "delete-me" > "$BASE/lower/to-delete.txt"

mount -t overlay overlay \
  -o "lowerdir=$BASE/lower,upperdir=$BASE/upper,workdir=$BASE/work" \
  "$BASE/merged"

log "1) merged видит файл из lower"
assert "merged/file.txt = original content" \
  bash -c '[[ "$(cat '"$BASE"'/merged/file.txt)" == "'"$ORIG"'" ]]'

log "2) после записи в merged — lower не изменён, upper содержит правку"
echo "modified" > "$BASE/merged/file.txt"
assert "lower/file.txt НЕ изменился (CoW защитил исходник)" \
  bash -c '[[ "$(cat '"$BASE"'/lower/file.txt)" == "'"$ORIG"'" ]]'
assert "upper/file.txt = modified" \
  bash -c '[[ "$(cat '"$BASE"'/upper/file.txt)" == "modified" ]]'

log "3) удаление в merged → whiteout (char device 0,0) в upper"
rm "$BASE/merged/to-delete.txt"
assert "upper/to-delete.txt — character device" \
  bash -c '[[ "$(stat -c "%F" '"$BASE"'/upper/to-delete.txt)" == "character special file" ]]'

# major:minor должны быть 0:0
DEV_MAJOR=$(stat -c '%t' "$BASE/upper/to-delete.txt")
DEV_MINOR=$(stat -c '%T' "$BASE/upper/to-delete.txt")
note "device major=$DEV_MAJOR minor=$DEV_MINOR (ожидаем 0/0)"
assert "whiteout = device 0,0" \
  bash -c '[[ "'"$DEV_MAJOR"'" == "0" && "'"$DEV_MINOR"'" == "0" ]]'

assert "merged больше не показывает удалённый файл" \
  bash -c '! [[ -e '"$BASE"'/merged/to-delete.txt ]]'

assert "lower всё ещё содержит файл (физически не удалён)" \
  test -f "$BASE/lower/to-delete.txt"

summary
