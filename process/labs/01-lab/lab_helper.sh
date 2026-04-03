#!/bin/bash
# ──────────────────────────────────────────────────────────────────
# lab_helper.sh — вспомогательный скрипт для лаба 01 (процессы)
#
# Использование:
#   bash lab_helper.sh
#   Выбери опцию в меню (1–5).
#
# Опция 5 — diagnostic challenge:
#   Запускает три процесса с намеренными проблемами.
#   Задача студента: найти все три проблемы через ps/proc/lsof/strace.
# ──────────────────────────────────────────────────────────────────

set -euo pipefail

PIDS=()  # собираем PID для cleanup

cleanup() {
    echo ""
    echo "[lab_helper] Завершение: останавливаю все запущенные процессы..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    # Убрать файл-флаг challenge
    rm -f /tmp/lab_challenge_running
    echo "[lab_helper] Готово."
}
trap cleanup EXIT INT TERM

# ── Опция 1: zombie farm ───────────────────────────────────────────
start_zombie_farm() {
    echo "[1] Запускаю zombie farm (5 зомби)..."
    python3 - <<'EOF' &
import os, time
for i in range(5):
    pid = os.fork()
    if pid == 0:
        os._exit(i)
print(f"[zombie_farm] Parent PID: {os.getpid()}, sleeping 120s without wait()...")
time.sleep(120)
EOF
    PIDS+=($!)
    echo "[1] Готово. PID родителя: ${PIDS[-1]}"
    echo "    Команда: ps aux | awk '\$8 ~ /Z/'"
}

# ── Опция 2: fd leak ──────────────────────────────────────────────
start_fd_leak() {
    echo "[2] Запускаю процесс с утечкой fd..."
    python3 - <<'EOF' &
import os, time, signal

# Игнорируем SIGTERM, чтобы процесс жил дольше для инспекции
signal.signal(signal.SIGTERM, signal.SIG_IGN)

fds = []
# Открываем 200 fd и НЕ закрываем — утечка
for _ in range(200):
    try:
        fds.append(os.open('/dev/null', os.O_RDONLY))
    except OSError:
        break

print(f"[fd_leak] PID={os.getpid()}, открыто {len(fds)} fd (утечка!), sleeping...")
time.sleep(300)
EOF
    PIDS+=($!)
    echo "[2] Готово. PID: ${PIDS[-1]}"
    echo "    Команда: ls /proc/${PIDS[-1]}/fd | wc -l"
    echo "             lsof -p ${PIDS[-1]} | wc -l"
}

# ── Опция 3: CPU-bound ────────────────────────────────────────────
start_cpu_bound() {
    echo "[3] Запускаю CPU-bound процесс (бесконечный цикл)..."
    python3 - <<'EOF' &
import os, time

print(f"[cpu_bound] PID={os.getpid()}, spinning forever...")
i = 0
while True:
    i += 1
EOF
    PIDS+=($!)
    echo "[3] Готово. PID: ${PIDS[-1]}"
    echo "    Команда: top -p ${PIDS[-1]}"
    echo "             cat /proc/${PIDS[-1]}/status | grep voluntary"
}

# ── Опция 4: I/O-bound ────────────────────────────────────────────
start_io_bound() {
    echo "[4] Запускаю I/O-bound процесс (бесконечная запись)..."
    bash -c 'while true; do dd if=/dev/zero of=/tmp/lab_io_test bs=4k count=256 2>/dev/null; done' &
    PIDS+=($!)
    echo "[4] Готово. PID: ${PIDS[-1]}"
    echo "    Команда: cat /proc/${PIDS[-1]}/status | grep voluntary"
    echo "             iostat -x 1 3"
    echo "    Очистка: rm -f /tmp/lab_io_test"
}

# ── Опция 5: diagnostic challenge ────────────────────────────────
start_challenge() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║         DIAGNOSTIC CHALLENGE — найди три проблемы       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Запускаю три процесса. Не читай код — диагностируй через:"
    echo "  ps aux, /proc/<PID>/*, lsof -p <PID>, strace -p <PID>"
    echo ""
    echo "Нажми Enter чтобы начать..."
    read -r

    touch /tmp/lab_challenge_running

    # ── Проблема 1: fd leak (200 открытых fd) ──────────────────
    python3 - <<'EOF' &
import os, time, signal
signal.signal(signal.SIGTERM, signal.SIG_IGN)
fds = []
for _ in range(200):
    try:
        fds.append(os.open('/dev/null', os.O_RDONLY))
    except OSError:
        break
# Маскируем под безобидное имя в ps
import sys
sys.argv[0] = 'data-processor'
print(f"[challenge] data-processor PID={os.getpid()} running", flush=True)
time.sleep(600)
EOF
    local pid1=$!
    PIDS+=($pid1)

    # ── Проблема 2: zombie farm (3 зомби) ──────────────────────
    python3 - <<'EOF' &
import os, time
for i in range(3):
    pid = os.fork()
    if pid == 0:
        os._exit(0)
import sys
sys.argv[0] = 'log-collector'
print(f"[challenge] log-collector PID={os.getpid()} running", flush=True)
time.sleep(600)
EOF
    local pid2=$!
    PIDS+=($pid2)

    # ── Проблема 3: CPU spin без видимой работы ─────────────────
    python3 - <<'EOF' &
import os, time, sys
sys.argv[0] = 'health-checker'
print(f"[challenge] health-checker PID={os.getpid()} running", flush=True)
i = 0
while True:
    i = (i + 1) % 1000000
EOF
    local pid3=$!
    PIDS+=($pid3)

    sleep 1  # дать процессам стартовать

    echo ""
    echo "─────────────────────────────────────────────────────────────"
    echo "Три процесса запущены:"
    echo "  data-processor  PID=$pid1"
    echo "  log-collector   PID=$pid2"
    echo "  health-checker  PID=$pid3"
    echo ""
    echo "Используй другой терминал для диагностики."
    echo "Подсказки:"
    echo "  ps aux | grep -E 'data-processor|log-collector|health-checker'"
    echo "  lsof -p $pid1 | wc -l"
    echo "  ps aux | awk '\$8 ~ /Z/'"
    echo "  top -p $pid3"
    echo ""
    echo "Нажми Enter когда закончишь диагностику (завершит процессы)..."
    read -r
}

# ── Меню ──────────────────────────────────────────────────────────
show_menu() {
    echo ""
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│             lab_helper.sh — меню                        │"
    echo "├─────────────────────────────────────────────────────────┤"
    echo "│  1. Запустить zombie farm (задание 10)                   │"
    echo "│  2. Запустить процесс с fd-утечкой (задание 12)          │"
    echo "│  3. Запустить CPU-bound процесс (задание 9)              │"
    echo "│  4. Запустить I/O-bound процесс (задание 9)              │"
    echo "│  5. Diagnostic challenge (задание 13) ← главное задание  │"
    echo "│  0. Выход                                                │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    printf "Выбери опцию [0–5]: "
    read -r choice

    case "$choice" in
        1) start_zombie_farm ;;
        2) start_fd_leak ;;
        3) start_cpu_bound ;;
        4) start_io_bound ;;
        5) start_challenge ; return ;;
        0) echo "Выход." ; exit 0 ;;
        *) echo "Неверная опция." ;;
    esac

    echo ""
    echo "Нажми Enter для возврата в меню..."
    read -r
}

while true; do
    show_menu
done
