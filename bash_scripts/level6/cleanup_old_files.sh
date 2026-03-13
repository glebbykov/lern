#!/bin/bash
# Удаление файлов старше N дней из директории
# Использование: ./cleanup_old_files.sh -d <директория> [-m <дней>] [-n] [-h]
#
# Флаги:
#   -d DIR   директория (обязательно)
#   -m N     возраст файлов в днях (по умолчанию: 30)
#   -n       dry-run: только показать, не удалять
#   -h       справка

set -euo pipefail

# ─── константы ────────────────────────────────────────────────────────────

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOCKFILE="/tmp/${SCRIPT_NAME%.sh}.lock"

# ─── вспомогательные функции ──────────────────────────────────────────────

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

usage() {
    cat <<EOF
Использование: $SCRIPT_NAME -d <директория> [-m <дней>] [-n] [-h]

Флаги:
  -d DIR   директория для очистки (обязательно)
  -m N     удалять файлы старше N дней (по умолчанию: 30)
  -n       dry-run: показать файлы, но не удалять
  -h       эта справка
EOF
}

acquire_lock() {
    if ! mkdir "$LOCKFILE" 2>/dev/null; then
        die "Скрипт уже запущен (lockfile: $LOCKFILE)"
    fi
    trap 'rm -rf "$LOCKFILE"; log "Завершение, lockfile удалён"' EXIT
    log "Lock получен: $LOCKFILE"
}

# ─── парсинг аргументов ───────────────────────────────────────────────────

TARGET_DIR=""
MIN_AGE_DAYS=30
DRY_RUN=false

while getopts "d:m:nh" opt; do
    case "$opt" in
        d) TARGET_DIR="$OPTARG" ;;
        m) MIN_AGE_DAYS="$OPTARG" ;;
        n) DRY_RUN=true ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# ─── валидация ────────────────────────────────────────────────────────────

[ -z "$TARGET_DIR" ] && { usage; die "Флаг -d обязателен"; }
[ -d "$TARGET_DIR" ] || die "Директория не существует: $TARGET_DIR"
[[ "$MIN_AGE_DAYS" =~ ^[0-9]+$ ]] || die "Значение -m должно быть числом"

# ─── основная логика ──────────────────────────────────────────────────────

main() {
    acquire_lock

    log "Целевая директория : $TARGET_DIR"
    log "Файлы старше       : ${MIN_AGE_DAYS} дней"
    log "Режим              : $( $DRY_RUN && echo 'DRY-RUN' || echo 'УДАЛЕНИЕ' )"
    log "---"

    local deleted=0
    local skipped=0

    while IFS= read -r file; do
        if $DRY_RUN; then
            log "[DRY-RUN] Удалить: $file"
        else
            rm -f "$file" && log "Удалён: $file" || { log "WARN: не удалось удалить: $file"; (( skipped++ )); continue; }
        fi
        (( deleted++ ))
    done < <(find "$TARGET_DIR" -maxdepth 1 -type f -mtime "+${MIN_AGE_DAYS}" 2>/dev/null)

    log "---"
    log "Обработано: $deleted | Пропущено: $skipped"
}

main
