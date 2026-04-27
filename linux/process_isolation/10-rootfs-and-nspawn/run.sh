#!/usr/bin/env bash
# Этап 10: качаем alpine, запускаем через systemd-nspawn.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require curl tar systemd-nspawn

ALPINE_DIR=/lab/10/alpine
ALPINE_VER=3.19.1
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-${ALPINE_VER}-x86_64.tar.gz"

log "1) скачиваем alpine minirootfs ($(echo $ALPINE_URL | sed 's|.*/||'))"
rm -rf /lab/10
mkdir -p "$ALPINE_DIR"
curl -fsSL "$ALPINE_URL" | tar -xz -C "$ALPINE_DIR"
note "размер: $(du -sh "$ALPINE_DIR" | cut -f1)"
note "файлов: $(find "$ALPINE_DIR" -type f | wc -l)"

log "2) запускаем через systemd-nspawn"
note "внутри: PID 1 наш, /etc/os-release alpine, hostname отдельный"
systemd-nspawn -q -D "$ALPINE_DIR" --pipe -- /bin/sh -c '
  echo "  hostname: $(hostname)"
  echo "  PID 1:    $(cat /proc/1/comm)"
  echo "  os:       $(grep PRETTY_NAME /etc/os-release)"
  echo "  uname:    $(uname -r)"
  echo "  ifaces:   $(ip a 2>/dev/null | grep -E "^[0-9]+:" | wc -l) (loopback only ⇒ изоляция сети)"
'

# ─── debootstrap (опционально) ───────────────────────────────────────────
if [[ "${WITH_DEBOOTSTRAP:-0}" = "1" ]] && command -v debootstrap >/dev/null; then
  UBUNTU_DIR=/lab/10/ubuntu
  log "3) debootstrap Ubuntu jammy minbase в $UBUNTU_DIR (~2 мин)"
  debootstrap --variant=minbase jammy "$UBUNTU_DIR" http://archive.ubuntu.com/ubuntu/ 2>&1 | tail -5
  note "размер: $(du -sh "$UBUNTU_DIR" | cut -f1)"
  log "запускаем ubuntu rootfs"
  systemd-nspawn -q -D "$UBUNTU_DIR" --pipe -- /bin/sh -c '
    echo "  os: $(grep PRETTY_NAME /etc/os-release)"
    echo "  apt: $(which apt)"
  '
else
  note "debootstrap пропущен (WITH_DEBOOTSTRAP=1 sudo ./run.sh — чтобы включить)"
fi

note "rootfs остаётся в $ALPINE_DIR — пригодится для capstone (этап 11)"
