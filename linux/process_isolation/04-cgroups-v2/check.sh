#!/usr/bin/env bash
# Автотест 04: реально ловим OOM, throttle, EAGAIN на pids.max.
# Тонкость: чтобы процесс ТОЧНО попал в cgroup перед тем как начать
# жрать ресурсы — используем `sh -c 'echo $$ > cgroup.procs; exec ...'`.
# Тогда "$$" внутри sh = его PID, и exec заменяет sh на целевой бинарь
# не теряя cgroup-членства.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require stress-ng

CG_ROOT=/sys/fs/cgroup
[[ -f "$CG_ROOT/cgroup.controllers" ]] || { echo "cgroups v2 не примонтирован" >&2; exit 1; }

# Проверим, что в корневом subtree_control включены нужные контроллеры
ROOT_SUB=$(cat "$CG_ROOT/cgroup.subtree_control")
for ctrl in memory cpu pids; do
  if ! grep -qw "$ctrl" <<<"$ROOT_SUB"; then
    echo "$ctrl не включён в $CG_ROOT/cgroup.subtree_control — пробуем включить"
    echo "+$ctrl" > "$CG_ROOT/cgroup.subtree_control" || \
      { echo "не удалось включить $ctrl" >&2; exit 1; }
  fi
done

mkdir -p "$CG_ROOT/lab-check"
# В этой группе включаем контроллеры для своих подгрупп
echo '+memory +cpu +pids' > "$CG_ROOT/lab-check/cgroup.subtree_control" 2>/dev/null || true

cleanup() {
  for d in "$CG_ROOT/lab-check/"*; do
    [[ -d "$d" ]] || continue
    [[ -f "$d/cgroup.procs" ]] && while read -r p; do echo "$p" > "$CG_ROOT/cgroup.procs" 2>/dev/null || true; done < "$d/cgroup.procs"
    rmdir "$d" 2>/dev/null || true
  done
  rmdir "$CG_ROOT/lab-check" 2>/dev/null || true
}
trap cleanup EXIT

# ─── memory: ловим OOM ────────────────────────────────────────────────────
mkdir -p "$CG_ROOT/lab-check/mem"
echo 32M > "$CG_ROOT/lab-check/mem/memory.max"
echo 0   > "$CG_ROOT/lab-check/mem/memory.swap.max"

# Запускаем stress-ng так, чтобы он гарантированно был в cgroup на момент аллокации
sh -c '
  echo $$ > '"$CG_ROOT"'/lab-check/mem/cgroup.procs
  exec stress-ng --vm 1 --vm-bytes 128M --vm-keep --vm-method zero-one --timeout 5s
' >/dev/null 2>&1 || true

OOM_COUNT=$(awk '/^oom_kill / {print $2}' "$CG_ROOT/lab-check/mem/memory.events")
note "memory.events oom_kill = $OOM_COUNT"
assert "memory.max=32M вызвал OOM-kill" \
  bash -c '[[ "'"${OOM_COUNT:-0}"'" -ge 1 ]]'

# ─── cpu: ловим throttle ──────────────────────────────────────────────────
mkdir -p "$CG_ROOT/lab-check/cpu"
echo "10000 100000" > "$CG_ROOT/lab-check/cpu/cpu.max"

sh -c '
  echo $$ > '"$CG_ROOT"'/lab-check/cpu/cgroup.procs
  exec timeout 3 bash -c "while :; do :; done"
' >/dev/null 2>&1 || true

THROTTLED=$(awk '/^nr_throttled/ {print $2}' "$CG_ROOT/lab-check/cpu/cpu.stat")
note "cpu.stat nr_throttled = $THROTTLED"
assert "cpu.max=10% вызвал throttling" \
  bash -c '[[ "'"${THROTTLED:-0}"'" -ge 1 ]]'

# ─── pids: ловим отказ fork ───────────────────────────────────────────────
mkdir -p "$CG_ROOT/lab-check/pids"
echo 3 > "$CG_ROOT/lab-check/pids/pids.max"

ERR_OUT=$(
  sh -c '
    echo $$ > '"$CG_ROOT"'/lab-check/pids/cgroup.procs
    for i in 1 2 3 4 5 6 7 8 9 10; do sleep 1 & done
    wait 2>/dev/null || true
  ' 2>&1
)
PIDS_FAIL=$(grep -c -i -E 'cannot fork|Resource temporarily' <<<"$ERR_OUT" || true)
note "fork-fail сообщений: $PIDS_FAIL"
assert "pids.max=3 заблокировал лишние fork" \
  bash -c '[[ "'"${PIDS_FAIL:-0}"'" -ge 1 ]]'

PIDS_MAX_EVENTS=$(awk '/^max ([0-9]+)/ {print $2}' "$CG_ROOT/lab-check/pids/pids.events")
note "pids.events max = $PIDS_MAX_EVENTS"
assert "pids.events.max > 0 (счётчик инкрементировался)" \
  bash -c '[[ "'"${PIDS_MAX_EVENTS:-0}"'" -ge 1 ]]'

summary
