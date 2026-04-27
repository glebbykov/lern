#!/usr/bin/env bash
# Автотест 01: собираем rootfs, проверяем что внутри chroot
# работает наш busybox и что побег через /proc/1/root проходит
# (это и есть «фича для демонстрации», не баг).
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require busybox

ROOT=/lab/01/check-rootfs
trap 'umount -l "$ROOT/proc" 2>/dev/null; umount -l "$ROOT/sys" 2>/dev/null; umount -l "$ROOT/dev" 2>/dev/null; rm -rf "$ROOT"' EXIT

rm -rf "$ROOT"
install -d "$ROOT"/{bin,etc,proc,sys,dev}
cp /bin/busybox "$ROOT/bin/" 2>/dev/null || cp /usr/bin/busybox "$ROOT/bin/"
ln -sf busybox "$ROOT/bin/sh"
ln -sf busybox "$ROOT/bin/cat"
ln -sf busybox "$ROOT/bin/echo"
ln -sf busybox "$ROOT/bin/hostname"
echo "chroot-jail" > "$ROOT/etc/hostname"

mount --rbind /dev "$ROOT/dev" >/dev/null 2>&1
mount --make-rslave "$ROOT/dev" >/dev/null 2>&1
mount -t proc proc "$ROOT/proc"
mount -t sysfs sys "$ROOT/sys"

assert "rootfs смонтирован, внутри запускается /bin/sh" \
  chroot "$ROOT" /bin/sh -c 'true'

assert "/etc/hostname внутри chroot = chroot-jail (ФС изолирована)" \
  bash -c '[[ "$(chroot "'"$ROOT"'" /bin/cat /etc/hostname)" == "chroot-jail" ]]'

# UTS не изолирован: hostname должен совпасть с хостовым.
HOST_HOSTNAME=$(hostname)
assert "hostname внутри chroot = hostname хоста (UTS общий)" \
  bash -c '[[ "$(chroot "'"$ROOT"'" /bin/hostname)" == "'"$HOST_HOSTNAME"'" ]]'

# Классический побег: должен сработать на чистом chroot.
assert "побег chroot /proc/1/root работает (защиты нет — это и доказываем)" \
  chroot "$ROOT" /bin/sh -c 'chroot /proc/1/root /bin/sh -c "echo escaped"'

summary
