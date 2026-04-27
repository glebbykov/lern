#!/usr/bin/env bash
# Автотест 02: для каждого namespace проверяем, что inode /proc/self/ns/<TYPE>
# отличается от хостового. Это самый честный способ — ядро гарантирует,
# что у двух процессов в РАЗНЫХ ns будут разные inode-номера.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require unshare

# inode хостового ns как «эталон»
host_ino() { stat -L -c '%i' "/proc/self/ns/$1"; }

inside_ino() {
  local kind="$1"; shift
  unshare "$@" --fork /bin/sh -c "stat -L -c '%i' /proc/self/ns/$kind" 2>/dev/null
}

check_ns() {
  local desc="$1" kind="$2"; shift 2
  local h i
  h=$(host_ino "$kind")
  i=$(inside_ino "$kind" "$@")
  if [[ -n "$i" && "$h" != "$i" ]]; then
    printf '%s ✓ %s (host=%s inside=%s)%s\n' "${C_GREEN}" "$desc" "$h" "$i" "${C_RESET}"
    PASS=$((PASS+1))
  else
    printf '%s ✗ %s (host=%s inside=%s)%s\n' "${C_RED}" "$desc" "$h" "$i" "${C_RESET}"
    FAIL=$((FAIL+1))
  fi
}

log "сравнение inode /proc/self/ns/* (отличается ⇒ мы в новом ns)"

check_ns "UTS namespace создан"   uts   --uts
check_ns "PID namespace создан"   pid   --pid --mount-proc
check_ns "MNT namespace создан"   mnt   --mount
check_ns "NET namespace создан"   net   --net
check_ns "IPC namespace создан"   ipc   --ipc
check_ns "USER namespace создан"  user  --user --map-root-user

log "функциональные проверки"

# UTS: сменили hostname внутри — снаружи не изменился
HOST_HN=$(hostname)
unshare --uts /bin/bash -c 'hostname iso-test'
assert "hostname хоста не изменился UTS-эффектом" \
  bash -c '[[ "$(hostname)" == "'"$HOST_HN"'" ]]'

# PID: внутри $$ должен быть 1
PID_INSIDE=$(unshare --pid --fork --mount-proc /bin/sh -c 'echo $$')
assert "внутри PID-ns: \$\$ == 1" \
  bash -c '[[ "'"$PID_INSIDE"'" == "1" ]]'

# MNT: tmpfs внутри не виден снаружи
unshare --mount /bin/bash -c '
  mount --make-rprivate / 2>/dev/null || true
  mount -t tmpfs none /mnt
  echo secret > /mnt/inside
'
assert "tmpfs из mnt-ns не утёк наружу" \
  bash -c '[[ ! -f /mnt/inside ]]'

# NET: внутри ровно 1 интерфейс (loopback, и тот down)
NET_IFACES=$(unshare --net /bin/sh -c 'ip -o link | wc -l')
assert "внутри net-ns ровно 1 интерфейс (loopback)" \
  bash -c '[[ "'"$NET_IFACES"'" == "1" ]]'

# USER: внутри uid=0
UID_INSIDE=$(unshare --user --map-root-user /bin/sh -c 'id -u')
assert "внутри user-ns uid=0" \
  bash -c '[[ "'"$UID_INSIDE"'" == "0" ]]'

summary
