#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/../scripts/lib.sh"

log "Тестируем eBPF (bpftrace)"

if ! command -v bpftrace >/dev/null; then
  echo "  - SKIP: bpftrace не установлен"
  exit 0
fi

echo "target" > /tmp/ebpf-target.txt

bash -c 'while true; do read line < /tmp/ebpf-target.txt 2>/dev/null; sleep 0.1; done' >/dev/null 2>&1 </dev/null &
PID=$!

timeout 3 bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf("BINGO: %s\n", str(args->filename)); }' > /tmp/ebpf-out.txt 2>/dev/null || true

kill -9 $PID 2>/dev/null || true

assert "bpftrace перехватил системный вызов openat и увидел имя файла" \
  grep -q 'BINGO: /tmp/ebpf-target.txt' /tmp/ebpf-out.txt

rm -f /tmp/ebpf-target.txt /tmp/ebpf-out.txt
summary
