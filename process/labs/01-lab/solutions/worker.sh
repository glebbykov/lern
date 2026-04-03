#!/bin/bash
# ──────────────────────────────────────────────────────────────────
# worker.sh — решение задания 6 (сигналы)
#
# Поведение:
#   SIGTERM  → graceful shutdown: сообщение, удалить lock, выйти
#   SIGINT   → игнорировать
#   SIGUSR1  → вывести статистику (итерации, uptime)
# ──────────────────────────────────────────────────────────────────

LOCKFILE="/tmp/worker.lock"
ITERATIONS=0
START_TIME=$(date +%s)

# ── Обработчики сигналов ──────────────────────────────────────────

handle_term() {
    echo ""
    echo "[worker] SIGTERM received — graceful shutdown"
    echo "[worker] Cleaning up lock file..."
    rm -f "$LOCKFILE"
    echo "[worker] Done. Exiting."
    exit 0
}

handle_usr1() {
    local now
    now=$(date +%s)
    local uptime=$((now - START_TIME))
    echo ""
    echo "[worker] ──── Status Report ────"
    echo "[worker] PID:        $$"
    echo "[worker] Iterations: $ITERATIONS"
    echo "[worker] Uptime:     ${uptime}s"
    echo "[worker] Lock file:  $(ls -la $LOCKFILE 2>/dev/null || echo 'MISSING')"
    echo "[worker] ────────────────────────"
}

# ── Установить trap ───────────────────────────────────────────────
trap handle_term SIGTERM
trap ''         SIGINT    # пустая строка = игнорировать
trap handle_usr1 SIGUSR1

# ── Создать lock-файл ─────────────────────────────────────────────
echo "$$" > "$LOCKFILE"
echo "[worker] Started. PID=$$, lock=$LOCKFILE"

# ── Основной цикл ────────────────────────────────────────────────
while true; do
    ITERATIONS=$((ITERATIONS + 1))
    echo "[worker] Working... (iteration $ITERATIONS)"
    sleep 2
done
