#!/usr/bin/env bash
# Автотест 03: pivot_root делает побег невозможным.
# ВАЖНО: после pivot_root исходный /tmp хоста недостижим. Поэтому
# результат проверок отправляем в STDOUT процесса unshare, который
# ещё в pid-ns родителя — родитель собирает stdout в переменную.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require unshare busybox

NEW=/lab/03/check-newroot
rm -rf /lab/03 && install -d "$NEW"

log "запускаем pivoted окружение и проверяем что побег не работает"

OUTPUT=$(unshare --mount --pid --uts --fork --mount-proc bash -c '
  set -e
  NEW='"$NEW"'
  mount -t tmpfs none "$NEW"
  install -d "$NEW"/{bin,etc,proc,tmp,old_root,dev}
  cp /bin/busybox "$NEW/bin/" 2>/dev/null || cp /usr/bin/busybox "$NEW/bin/"
  for app in sh ash cat hostname ls chroot mount umount echo true grep tr; do
    ln -sf busybox "$NEW/bin/$app"
  done
  echo pivoted > "$NEW/etc/hostname"
  mount -t proc proc "$NEW/proc"

  # /dev/null нужен для shell-перенаправлений ПОСЛЕ pivot
  /bin/busybox mknod "$NEW/dev/null" c 1 3 2>/dev/null || true
  chmod 666 "$NEW/dev/null"

  cd "$NEW"
  pivot_root . old_root
  /bin/busybox umount -l /old_root
  export PATH=/bin

  # после pivot работаем только bash-builtins + явные /bin/busybox-аплеты
  hostname pivoted-test
  HN=$(hostname)
  printf "host_hostname=%s\n" "$HN"

  # ls без tr — собираем имена в строку через bash-glob
  shopt -s nullglob; entries=( /* )
  joined=""
  for e in "${entries[@]}"; do joined="$joined${e##*/},"; done
  printf "ls_root=%s\n" "$joined"

  # пробуем побег. Сама команда chroot успешна — но важно КУДА она
  # привела. Если в нашу же tmpfs (= виден pivoted-test hostname и наши
  # минимальные /bin,/etc,/proc,/tmp), то это CONFINED. Если в корень
  # хоста — там будут /home, /usr, /var и т.п.
  ESCAPE_LS=$(/bin/chroot /proc/1/root /bin/sh -c "/bin/busybox ls / 2>/dev/null || ls /" 2>/dev/null || echo "FAIL")
  printf "escape_ls=%s\n" "$(echo "$ESCAPE_LS" | tr "\n" ",")"
  if echo "$ESCAPE_LS" | grep -qE "(home|usr|var)"; then
    printf "escape=ESCAPED\n"
  else
    printf "escape=CONFINED\n"
  fi
' 2>&1)

note "вывод pivoted-окружения:"
echo "$OUTPUT" | sed 's/^/   /'

assert "вывод от pivoted-окружения непустой" \
  bash -c '[[ -n "'"$OUTPUT"'" ]]'

assert "побег chroot /proc/1/root заблокирован после pivot_root" \
  bash -c 'grep -q "escape=CONFINED" <<<"'"$OUTPUT"'"'

assert "hostname в pivoted = pivoted-test (UTS изолирован)" \
  bash -c 'grep -q "host_hostname=pivoted-test" <<<"'"$OUTPUT"'"'

# Проверяем минимальность нового корня — там не должно быть /home, /var, /usr (мы их не создавали)
assert "корень минимальный — нет /home в новом корне" \
  bash -c 'L=$(grep ^ls_root <<<"'"$OUTPUT"'" | cut -d= -f2); ! [[ "$L" == *"home"* ]]'

assert "корень минимальный — нет /var в новом корне" \
  bash -c 'L=$(grep ^ls_root <<<"'"$OUTPUT"'" | cut -d= -f2); ! [[ "$L" == *"var,"* ]]'

summary
