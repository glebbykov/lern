#!/usr/bin/env bash
# Этап 06: показываем seccomp двумя способами — через systemd-run
# и через сырой seccomp-bpf на Python ctypes.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require systemd-run python3

# ─── способ 1: systemd-run ────────────────────────────────────────────────
log "1) systemd-run -p SystemCallFilter=~uname uname"
note "тильда (~) перед uname означает 'запретить', без неё — 'разрешить только'"
systemd-run --wait --collect -q -p SystemCallFilter=~uname uname -a 2>&1 | head -3 || true
note "exit code != 0, сервис убит SIGSYS"

# ─── способ 2: блокировка целой группы ─────────────────────────────────────
log "2) systemd-run -p SystemCallFilter=~@privileged ip link add"
note "@privileged = ~50 syscalls для admin-операций"
systemd-run --wait --collect -q -p SystemCallFilter=~@privileged \
  ip link add fake type dummy 2>&1 | head -3 || true

# ─── способ 3: сырой seccomp-bpf ──────────────────────────────────────────
log "3) свой seccomp-bpf через ctypes — блокируем uname (syscall 63 на x86_64)"
note "запускаем uname под фильтром; ожидаем SIGSYS"
"$(dirname "$0")/seccomp_bpf.py" 63 uname -a 2>&1 | head -3 || true
echo "  exit code: $?"

log "4) тот же фильтр, но команда date — она НЕ зовёт uname → работает"
"$(dirname "$0")/seccomp_bpf.py" 63 date

log "5) проверяем что нашему текущему шеллу seccomp не применён"
grep Seccomp /proc/self/status | sed 's/^/  /'
note "Seccomp: 0 = не активен, 1 = strict, 2 = filter (наш способ)"
