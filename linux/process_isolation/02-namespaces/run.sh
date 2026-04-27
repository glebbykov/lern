#!/usr/bin/env bash
# Этап 02: разбираем 6 типов namespaces по одному.
set -euo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require unshare ip nsenter

show_ns() {
  local label="$1"
  echo "  [$label] uts=$(readlink /proc/self/ns/uts) pid=$(readlink /proc/self/ns/pid)" \
       "mnt=$(readlink /proc/self/ns/mnt) net=$(readlink /proc/self/ns/net)" \
       "ipc=$(readlink /proc/self/ns/ipc) user=$(readlink /proc/self/ns/user)"
}

log "namespaces текущей оболочки (для сравнения)"
show_ns host

# ─────────────────────────────────────────────────────────────────────────────
log "UTS namespace: свой hostname"
unshare --uts /bin/bash -c '
  hostname container-uts
  echo "  внутри: hostname=$(hostname)  ns=$(readlink /proc/self/ns/uts)"
'
note "снаружи hostname остался: $(hostname)"

# ─────────────────────────────────────────────────────────────────────────────
log "PID namespace: PID 1 — это наш процесс"
unshare --pid --fork --mount-proc /bin/bash -c '
  echo "  внутри:  $$ это PID 1"
  ps -ef | head -3
  echo "  ns=$(readlink /proc/self/ns/pid)"
'

# ─────────────────────────────────────────────────────────────────────────────
log "MNT namespace: свой /mnt не виден хосту"
unshare --mount /bin/bash -c '
  mount --make-rprivate /
  mount -t tmpfs none /mnt
  echo secret > /mnt/inside
  echo "  внутри:  /mnt содержит: $(ls /mnt)"
  echo "  ns=$(readlink /proc/self/ns/mnt)"
'
note "снаружи /mnt пустой? $(ls /mnt 2>/dev/null || echo нет такой папки)"

# ─────────────────────────────────────────────────────────────────────────────
log "NET namespace: пустой сетевой стек"
unshare --net /bin/bash -c '
  ip link
  echo "  ns=$(readlink /proc/self/ns/net)"
'
note "только loopback и тот выключен — никаких eth0, никакой связности"

# ─────────────────────────────────────────────────────────────────────────────
log "USER namespace: rootless"
note "внутри будем uid=0, снаружи останемся uid $(id -u)"
unshare --user --map-root-user /bin/bash -c '
  echo "  внутри: $(id)"
  echo "  ns=$(readlink /proc/self/ns/user)"
'

# ─────────────────────────────────────────────────────────────────────────────
log "IPC namespace: своя SysV-таблица"
note "ipcs -m снаружи и внутри показывает разные таблицы"
unshare --ipc /bin/bash -c '
  ipcs -m | head -5
  echo "  ns=$(readlink /proc/self/ns/ipc)"
'

# ─────────────────────────────────────────────────────────────────────────────
log "ВСЁ СРАЗУ: одной командой 6 namespaces"
unshare --uts --pid --mount --net --ipc --user --map-root-user --fork --mount-proc \
  /bin/bash -c '
    hostname mini-container
    echo "  hostname:  $(hostname)"
    echo "  uid:       $(id -u)"
    echo "  PID 1:     $(cat /proc/1/comm)"
    echo "  ifaces:    $(ip -o link | wc -l)"
    echo "  это и есть базовый docker run"
  '
