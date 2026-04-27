#!/usr/bin/env bash
# Этап 01: собираем busybox-rootfs, заходим в chroot, показываем что
# изолировано (только ФС) и что нет (PID, UTS, NET).
set -euo pipefail
. "$(dirname "$0")/../scripts/lib.sh"

require unshare busybox

ROOT=/lab/01/rootfs
log "готовим минимальный rootfs в $ROOT"
rm -rf /lab/01
install -d -m 0755 "$ROOT"/{bin,etc,proc,sys,dev,root,tmp}
chmod 1777 "$ROOT/tmp"

cp /bin/busybox "$ROOT/bin/" || cp /usr/bin/busybox "$ROOT/bin/"
# создаём симлинки sh/ls/cat/echo/ps/mount/uname → busybox
for app in sh ash ls cat echo ps mount uname id hostname grep; do
  ln -sf busybox "$ROOT/bin/$app"
done

# минимум /etc, чтобы программы не падали
cat > "$ROOT/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/:/bin/sh
EOF
cat > "$ROOT/etc/group" <<'EOF'
root:x:0:
nobody:x:65534:
EOF
echo "chroot-jail" > "$ROOT/etc/hostname"

log "монтируем псевдо-ФС в rootfs"
mount --rbind /dev "$ROOT/dev"
mount --make-rslave "$ROOT/dev"
mount -t proc proc "$ROOT/proc"
mount -t sysfs sys "$ROOT/sys"
note "это нужно чтобы внутри работали ps, mount, /dev/null"

log "входим в chroot и проверяем границы"
chroot "$ROOT" /bin/sh -c '
  echo "--- внутри chroot ---"
  echo "PID процесса: $$ (это PID в namespace хоста — НЕ изолировано)"
  echo "/etc/hostname: $(cat /etc/hostname)  (наш файл из rootfs)"
  echo "hostname:      $(hostname)            (берётся из UTS — общий с хостом)"
  echo "ls /:"; ls /
  echo "ps (видим процессы хоста):"; ps | head -5
'

log "демонстрация классического chroot escape через /proc/1/root"
note "/proc/<pid>/root — magic-symlink на корень процесса в его mnt-ns"
note "так как mnt-ns общий, /proc/1/root указывает на корень ХОСТА"
chroot "$ROOT" /bin/sh -c '
  echo "Внутри сбегающего chroot, hostname моего корня хоста:"
  chroot /proc/1/root /bin/sh -c "hostname; echo сидим в корне ХОСТА"
'

log "приборка"
umount -l "$ROOT/proc" "$ROOT/sys" "$ROOT/dev" 2>/dev/null || true
note "rootfs оставлен в /lab/01 на случай если хочешь поковырять"
