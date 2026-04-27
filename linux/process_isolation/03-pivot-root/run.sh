#!/usr/bin/env bash
# Этап 03: pivot_root внутри mnt-ns. После этого побег chroot /proc/1/root
# уже не работает — корень хоста недостижим.
set -euo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require unshare busybox

NEW=/lab/03/newroot
log "готовим $NEW (это станет корнем)"
rm -rf /lab/03
install -d "$NEW"

# unshare запускает дочерний bash с уже разделённым mount/pid/uts namespace.
# В нём примонтируем tmpfs в NEW (отдельная ФС — обязательно для pivot_root),
# заполним минимальным rootfs и сделаем pivot.
log "входим в новый mnt+pid ns и делаем pivot_root"

unshare --mount --pid --uts --fork --mount-proc bash <<'INNER'
set -euo pipefail
NEW=/lab/03/newroot

# tmpfs — гарантированно отдельная ФС, pivot_root любит такое
mount -t tmpfs none "$NEW"

# минимальный rootfs (busybox + симлинки)
install -d "$NEW"/{bin,etc,proc,sys,dev,old_root}
cp /bin/busybox "$NEW/bin/" 2>/dev/null || cp /usr/bin/busybox "$NEW/bin/"
for app in sh ls cat echo ps mount umount hostname; do
  ln -sf busybox "$NEW/bin/$app"
done
echo "pivoted-container" > "$NEW/etc/hostname"

# монтируем proc и dev для нового корня
mount -t proc proc "$NEW/proc"
mount --rbind /dev "$NEW/dev"

cd "$NEW"
pivot_root . old_root

# теперь "/" — это новый rootfs, старый — в /old_root
hostname pivoted-container
echo "  внутри pivoted: hostname=$(hostname)"
echo "  /old_root — это бывший хост-корень, временно виден:"
ls /old_root | head -5

# отмонтируем старый корень — после этого хост-корень полностью недостижим
umount -l /old_root

echo "  попытка попасть в старый корень (должна провалиться):"
ls /old_root 2>&1 || echo "  → нет такого пути"
echo "  /proc/1/root теперь ведёт в наш новый корень:"
ls /proc/1/root | head -5
INNER
