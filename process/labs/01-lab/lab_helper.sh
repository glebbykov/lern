#!/bin/bash
# ──────────────────────────────────────────────────────────────────
# lab_helper.sh — вспомогательный скрипт для лаба 01 (процессы)
#
# Использование:
#   bash lab_helper.sh
#   Выбери опцию в меню (1–6).
#
# Опция 5 — diagnostic challenge:
#   Запускает четыре процесса с намеренными проблемами.
#   Задача студента: найти все четыре проблемы через ps/proc/lsof/strace.
#
# Опция 6 — быстрая проверка всех инструментов.
# ──────────────────────────────────────────────────────────────────

set -euo pipefail

PIDS=()  # собираем PID для cleanup

cleanup() {
    echo ""
    echo "[lab_helper] Завершение: останавливаю все запущенные процессы..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
        # подождём чтобы зомби тоже ушли
        wait "$pid" 2>/dev/null || true
    done
    rm -f /tmp/lab_challenge_running /tmp/lab_io_test /tmp/lab_bigfile_holder.dat
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
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║       DIAGNOSTIC CHALLENGE — найди четыре проблемы         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Запускаю четыре процесса. Не читай код — диагностируй через:"
    echo "  ps aux, /proc/<PID>/*, lsof -p <PID>, strace -p <PID>"
    echo ""
    echo "Нажми Enter чтобы начать..."
    read -r

    touch /tmp/lab_challenge_running

    # ── Проблема 1: fd leak (200 открытых fd) ──────────────────
    python3 - <<'EOF' &
import os, time, signal, sys
signal.signal(signal.SIGTERM, signal.SIG_IGN)
fds = []
for _ in range(200):
    try:
        fds.append(os.open('/dev/null', os.O_RDONLY))
    except OSError:
        break
# Маскируем под безобидное имя в ps
sys.argv[0] = 'data-processor'
print(f"[challenge] data-processor PID={os.getpid()} running", flush=True)
time.sleep(600)
EOF
    local pid1=$!
    PIDS+=($pid1)

    # ── Проблема 2: zombie farm (3 зомби) ──────────────────────
    python3 - <<'EOF' &
import os, time, sys
for i in range(3):
    pid = os.fork()
    if pid == 0:
        os._exit(0)
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

    # ── Проблема 4: удалённый файл, удерживаемый fd ─────────────
    # Процесс создаёт файл 50 МБ, открывает его, удаляет с диска
    # и продолжает читать. df показывает 50 МБ занято, du — нет.
    # Диагностика: lsof +L1, /proc/PID/fd → (deleted)
    python3 - <<'EOF' &
import os, time, sys

sys.argv[0] = 'cache-warmer'
filepath = '/tmp/lab_bigfile_holder.dat'

# Создать файл 50 МБ
with open(filepath, 'wb') as f:
    f.write(b'\x00' * 50 * 1024 * 1024)

# Открыть и удалить — inode held, блоки не освобождены
fd = os.open(filepath, os.O_RDONLY)
os.unlink(filepath)

print(f"[challenge] cache-warmer PID={os.getpid()} running (holding deleted 50MB file)", flush=True)

# Периодически читать чтобы выглядело как работа
while True:
    os.lseek(fd, 0, os.SEEK_SET)
    os.read(fd, 4096)
    time.sleep(5)
EOF
    local pid4=$!
    PIDS+=($pid4)

    sleep 1  # дать процессам стартовать

    echo ""
    echo "─────────────────────────────────────────────────────────────"
    echo "Четыре процесса запущены:"
    echo "  data-processor  PID=$pid1"
    echo "  log-collector   PID=$pid2"
    echo "  health-checker  PID=$pid3"
    echo "  cache-warmer    PID=$pid4"
    echo ""
    echo "Используй другой терминал для диагностики."
    echo ""
    echo "Подсказки (не смотри сразу — попробуй найти сам):"
    echo "  ps aux | grep -E 'data-processor|log-collector|health-checker|cache-warmer'"
    echo "  lsof -p <PID> | wc -l"
    echo "  ps aux | awk '\$8 ~ /Z/'"
    echo "  top -p <PID>"
    echo "  sudo lsof +L1"
    echo "  ls -la /proc/<PID>/fd/"
    echo ""
    echo "Нажми Enter когда закончишь диагностику (завершит процессы)..."
    read -r
}

# ── Опция 6: проверка инструментов ────────────────────────────────
check_tools() {
    echo ""
    echo "Проверка установленных инструментов:"
    echo ""
    local tools=("gcc" "pstree" "tmux" "lsof" "strace" "python3" "iostat")
    local missing=0
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            printf "  %-12s ✓ %s\n" "$tool" "$(command -v "$tool")"
        else
            printf "  %-12s ✗ НЕ УСТАНОВЛЕН\n" "$tool"
            ((missing++)) || true
        fi
    done
    echo ""
    if [[ $missing -gt 0 ]]; then
        echo "Установи недостающее:"
        echo "  sudo apt install -y gcc build-essential psmisc tmux lsof python3 strace sysstat"
    else
        echo "Всё установлено ✓"
    fi
}

# ── Меню ──────────────────────────────────────────────────────────
show_menu() {
    echo ""
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│              lab_helper.sh — меню                            │"
    echo "├──────────────────────────────────────────────────────────────┤"
    echo "│  1. Запустить zombie farm (задание 10)                       │"
    echo "│  2. Запустить процесс с fd-утечкой (задание 12)              │"
    echo "│  3. Запустить CPU-bound процесс (задание 9)                  │"
    echo "│  4. Запустить I/O-bound процесс (задание 9)                  │"
    echo "│  5. Diagnostic challenge (задание 13) ← главное задание      │"
    echo "│  6. Проверить установку инструментов                         │"
    echo "│  0. Выход                                                    │"
    echo "└──────────────────────────────────────────────────────────────┘"
    echo ""
    printf "Выбери опцию [0–6]: "
    read -r choice

    case "$choice" in
        1) start_zombie_farm ;;
        2) start_fd_leak ;;
        3) start_cpu_bound ;;
        4) start_io_bound ;;
        5) start_challenge ; return ;;
        6) check_tools ;;
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
