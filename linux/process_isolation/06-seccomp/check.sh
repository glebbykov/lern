#!/usr/bin/env bash
# Автотест 06: оба пути блокировки реально приводят к ненулевому exit.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require systemd-run python3

log "systemd-run path: SystemCallFilter=~uname блокирует uname"
assert_fail "uname под systemd seccomp падает (SIGSYS)" \
  systemd-run --wait --collect -q -p SystemCallFilter=~uname uname -a

log "systemd-run path: фильтр НЕ применённый к команде — она работает"
assert "echo под systemd-run без фильтра — exit 0" \
  systemd-run --wait --collect -q echo hello

log "raw seccomp-bpf: блокировка uname (syscall 63 x86_64) убивает uname"
assert_fail "uname под нашим bpf-фильтром падает" \
  "$(dirname "$0")/seccomp_bpf.py" 63 uname -a

log "raw seccomp-bpf: незатронутая команда работает"
assert "date под bpf-фильтром на uname работает" \
  "$(dirname "$0")/seccomp_bpf.py" 63 date

log "после prctl фильтр виден в /proc/<pid>/status"
SECCOMP_MODE=$("$(dirname "$0")/seccomp_bpf.py" 63 cat /proc/self/status 2>/dev/null | awk '/^Seccomp:/ {print $2}')
note "Seccomp: $SECCOMP_MODE (ожидаем 2 = MODE_FILTER)"
assert "Seccomp mode = 2 (filter) после установки фильтра" \
  bash -c '[[ "'"$SECCOMP_MODE"'" == "2" ]]'

summary
