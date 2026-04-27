#!/usr/bin/env bash
# mycontainer — минимальный «docker run» из примитивов ядра.
#
# Usage:
#   sudo ./mycontainer.sh run [-m MEM] [-c CPU] [-p PIDS] IMAGE -- CMD [ARGS...]
#   sudo ./mycontainer.sh run alpine -- sh
#
# IMAGE: alpine | путь к rootfs
# Дефолты: -m 128M -c 50% -p 64
#
# Внутри собирает по очереди:
#   1) overlay (lower=image rootfs, upper=container rw)
#   2) cgroup v2 с лимитами
#   3) namespaces: uts/pid/mnt/ipc + (опц) net
#   4) pivot_root в merged
#   5) cap_drop ALL
#   6) seccomp-bpf (через 06-seccomp/seccomp_bpf.py если рядом)
#   7) exec команды

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/../scripts/lib.sh"
require unshare ip mount

usage() { sed -n '2,15p' "$0" >&2; exit 2; }

[[ "${1:-}" == "run" ]] || usage
shift

MEM=128M
CPU="50000 100000"   # 50% одного ядра
PIDS=64
while [[ "${1:-}" == -* ]]; do
  case "$1" in
    -m) MEM="$2"; shift 2;;
    -c) CPU="$2"; shift 2;;
    -p) PIDS="$2"; shift 2;;
    -h) usage;;
    --) shift; break;;
    *)  usage;;
  esac
done

IMAGE="${1:?нужен IMAGE (alpine или путь к rootfs)}"; shift
[[ "${1:-}" == "--" ]] && shift
CMD=("$@")
[[ ${#CMD[@]} -gt 0 ]] || CMD=(sh)

CID="myc-$(date +%s)-$$"
STATE_DIR="/var/lib/mycontainer/${CID}"
ALPINE_DIR=/lab/10/alpine

# ── 1. Готовим image rootfs ────────────────────────────────────────────────
if [[ "$IMAGE" == "alpine" ]]; then
  if ! [[ -d "$ALPINE_DIR" ]] || ! [[ -x "$ALPINE_DIR/bin/sh" ]]; then
    log "alpine rootfs не найден, качаю в $ALPINE_DIR"
    rm -rf /lab/10
    mkdir -p "$ALPINE_DIR"
    curl -fsSL "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.1-x86_64.tar.gz" \
      | tar -xz -C "$ALPINE_DIR"
  fi
  IMAGE_ROOTFS="$ALPINE_DIR"
elif [[ -d "$IMAGE" ]]; then
  IMAGE_ROOTFS="$IMAGE"
else
  echo "не нашёл rootfs: $IMAGE" >&2; exit 1
fi

# ── 2. Готовим overlay (этап 08) ───────────────────────────────────────────
mkdir -p "$STATE_DIR"/{upper,work,merged}
mount -t overlay overlay \
  -o "lowerdir=$IMAGE_ROOTFS,upperdir=$STATE_DIR/upper,workdir=$STATE_DIR/work" \
  "$STATE_DIR/merged"
log "overlay смонтирован: $STATE_DIR/merged"

# ── 3. cgroup v2 (этап 04) ─────────────────────────────────────────────────
CG="/sys/fs/cgroup/mycontainer-${CID}"
mkdir -p "/sys/fs/cgroup/mycontainer"
echo '+memory +cpu +pids' > "/sys/fs/cgroup/mycontainer/cgroup.subtree_control" 2>/dev/null || true
mkdir -p "$CG"
echo "$MEM" > "$CG/memory.max"
echo 0      > "$CG/memory.swap.max"
echo "$CPU" > "$CG/cpu.max"
echo "$PIDS" > "$CG/pids.max"
log "cgroup создан: $CG  (mem=$MEM cpu=$CPU pids=$PIDS)"

# ── 4-7. namespaces + pivot_root + caps + seccomp + exec ───────────────────
log "запускаем контейнер ${CID}"

# Скрипт, который выполнится внутри namespace (см. //CHILD ниже)
CHILD_SCRIPT=$(cat <<'CHILD'
set -euo pipefail
STATE_DIR="$1"; shift
CG="$1"; shift
SECCOMP_HELPER="$1"; shift

# поместить себя в cgroup
echo $$ > "$CG/cgroup.procs"

# смонтируем proc/sys/dev в overlay merged
mount -t proc proc "$STATE_DIR/merged/proc"
mount -t sysfs sys "$STATE_DIR/merged/sys" 2>/dev/null || true
mount --rbind /dev "$STATE_DIR/merged/dev"

# pivot_root в merged
mkdir -p "$STATE_DIR/merged/old_root"
cd "$STATE_DIR/merged"
pivot_root . old_root
umount -l /old_root
rmdir /old_root 2>/dev/null || true

# дропаем все capabilities
# capsh --drop=ALL запускает sh уже без капов; мы не хотим терять
# CAP_SYS_CHROOT etc. ДО pivot_root, поэтому снимаем сейчас.
# В минимальном alpine capsh нет — пропустим, если нет.
if command -v capsh >/dev/null 2>&1; then
  exec capsh --drop=all -- -c '
    hostname mycontainer
    exec "$@"
  ' -- "$@"
fi

# Без capsh: используем prctl напрямую через python (если есть seccomp helper).
if [[ -n "$SECCOMP_HELPER" && -x "$SECCOMP_HELPER" ]]; then
  hostname mycontainer 2>/dev/null || true
  # 169 = settimeofday — заведомо безопасно блокировать
  exec "$SECCOMP_HELPER" 169 "$@"
fi

hostname mycontainer 2>/dev/null || true
exec "$@"
CHILD
)

SECCOMP_HELPER="${SCRIPT_DIR}/../06-seccomp/seccomp_bpf.py"
[[ -x "$SECCOMP_HELPER" ]] || SECCOMP_HELPER=""

# unshare всех ns + mount-proc
unshare --uts --pid --mount --ipc --fork --mount-proc \
  /bin/bash -c "$CHILD_SCRIPT" -- "$STATE_DIR" "$CG" "$SECCOMP_HELPER" "${CMD[@]}"

EXIT_CODE=$?

# ── чистим за собой ────────────────────────────────────────────────────────
log "завершение, чистим"
umount -l "$STATE_DIR/merged" 2>/dev/null || true
rmdir "$CG" 2>/dev/null || true
rm -rf "$STATE_DIR"

exit "$EXIT_CODE"
