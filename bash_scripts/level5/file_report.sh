#!/bin/bash
# Отчёт по файлам в директории: количество, суммарный размер, топ расширений
# Использование: ./file_report.sh <директория>

# ─── вспомогательные функции ───────────────────────────────────────────────

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

count_files() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l
}

total_size_kb() {
    local dir="$1"
    du -sk "$dir" 2>/dev/null | cut -f1
}

top_extensions() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type f 2>/dev/null \
        | sed 's/.*\.//' \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -5
}

# ─── основная логика ───────────────────────────────────────────────────────

main() {
    local dir="${1:-.}"

    [ -d "$dir" ] || die "Директория '$dir' не существует"

    local file_count
    file_count=$(count_files "$dir") || die "Ошибка подсчёта файлов"

    local size_kb
    size_kb=$(total_size_kb "$dir") || die "Ошибка подсчёта размера"

    log "=== Отчёт: $dir ==="
    log "Файлов (без поддиректорий): $file_count"
    log "Суммарный размер директории: ${size_kb} КБ"
    log ""
    log "Топ расширений:"
    top_extensions "$dir" | while read -r line; do
        log "  $line"
    done
}

main "$@"
