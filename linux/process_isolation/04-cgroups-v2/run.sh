#!/usr/bin/env bash
# Этап 04: показываем 4 контроллера cgroup v2 в действии.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require stress-ng

CG_ROOT=/sys/fs/cgroup
[[ -f "$CG_ROOT/cgroup.controllers" ]] || { echo "cgroups v2 не примонтирован" >&2; exit 1; }

# включаем нужные контроллеры в дочернюю поддиректорию (на root-cgroup нельзя добавить процессы и контроллеры одновременно)
mkdir -p "$CG_ROOT/lab"
echo '+memory +cpu +pids +io' > "$CG_ROOT/lab/cgroup.subtree_control" 2>/dev/null || true

cleanup() {
  for d in "$CG_ROOT/lab/"*; do
    [[ -d "$d" ]] || continue
    # выгнать всех процессов в корень
    if [[ -f "$d/cgroup.procs" ]]; then
      while read -r pid; do echo "$pid" > "$CG_ROOT/cgroup.procs" 2>/dev/null || true; done < "$d/cgroup.procs"
    fi
    rmdir "$d" 2>/dev/null || true
  done
  rmdir "$CG_ROOT/lab" 2>/dev/null || true
}
trap cleanup EXIT

# ─── memory ────────────────────────────────────────────────────────────────
log "memory.max=64M, грузим 256M через stress-ng → OOM"
mkdir -p "$CG_ROOT/lab/mem"
echo 64M > "$CG_ROOT/lab/mem/memory.max"
echo 0   > "$CG_ROOT/lab/mem/memory.swap.max"  # запретить swap, чтобы OOM был быстрым

(
  echo $$ > "$CG_ROOT/lab/mem/cgroup.procs"
  exec stress-ng --vm 1 --vm-bytes 256M --vm-keep --timeout 5s
) || true

note "memory.events:"
cat "$CG_ROOT/lab/mem/memory.events" | sed 's/^/   /'

# ─── cpu ───────────────────────────────────────────────────────────────────
log "cpu.max=20000 100000 (20% ядра), запускаем busy-loop"
mkdir -p "$CG_ROOT/lab/cpu"
echo "20000 100000" > "$CG_ROOT/lab/cpu/cpu.max"

(
  echo $$ > "$CG_ROOT/lab/cpu/cpu.procs" 2>/dev/null || true
  echo $$ > "$CG_ROOT/lab/cpu/cgroup.procs"
  exec timeout 3 bash -c 'while :; do :; done'
) || true

note "cpu.stat:"
grep -E '^(usage_usec|throttled_usec|nr_throttled)' "$CG_ROOT/lab/cpu/cpu.stat" | sed 's/^/   /'

# ─── pids ──────────────────────────────────────────────────────────────────
log "pids.max=5, пробуем заспаунить 20 sleep-процессов"
mkdir -p "$CG_ROOT/lab/pids"
echo 5 > "$CG_ROOT/lab/pids/pids.max"

(
  echo $$ > "$CG_ROOT/lab/pids/cgroup.procs"
  for i in $(seq 1 20); do
    sleep 0.5 &
  done
  wait 2>/dev/null || true
) 2>&1 | head -10

note "pids.events:"
cat "$CG_ROOT/lab/pids/pids.events" | sed 's/^/   /'

# ─── io (best effort) ──────────────────────────────────────────────────────
log "io.max — попробуем ограничить запись на корневой диск"
ROOT_DEV=$(findmnt -no SOURCE / | head -n1 | sed 's/[0-9]*$//')
MAJ_MIN=$(lsblk -no MAJ:MIN "$ROOT_DEV" 2>/dev/null | head -n1 | tr -d ' ')
if [[ -n "$MAJ_MIN" ]]; then
  mkdir -p "$CG_ROOT/lab/io"
  echo "$MAJ_MIN wbps=1048576" > "$CG_ROOT/lab/io/io.max" 2>/dev/null \
    && note "io.max установлен: $MAJ_MIN wbps=1MB/s" \
    || note "io.max не применился (нужен io controller / другая ФС)"
else
  note "не определил MAJ:MIN корневого диска, io пропущен"
fi
