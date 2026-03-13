#!/bin/bash
# Поиск крупных файлов в директории
# Использование: ./find_large_files.sh <директория> [минимальный размер в МБ]

# ─── вспомогательные функции ───────────────────────────────────────────────

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

check_dir() {
    local dir="$1"
    [ -z "$dir" ] && die "Укажите директорию как первый аргумент"
    [ -d "$dir" ] || die "Директория '$dir' не существует"
    [ -r "$dir" ] || die "Нет прав на чтение директории '$dir'"
}

# ─── основная логика ───────────────────────────────────────────────────────

main() {
    local dir="${1:-.}"
    local min_mb="${2:-10}"
    local min_kb=$(( min_mb * 1024 ))

    check_dir "$dir"

    log "Поиск файлов крупнее ${min_mb} МБ в: $dir"
    log "---"

    local count=0
    while IFS= read -r file; do
        local size_kb
        size_kb=$(du -k "$file" 2>/dev/null | cut -f1)
        local size_mb=$(( size_kb / 1024 ))
        printf "  %5d МБ  %s\n" "$size_mb" "$file"
        (( count++ ))
    done < <(find "$dir" -type f -size "+${min_kb}k" 2>/dev/null | sort)

    log "---"
    if [ "$count" -eq 0 ]; then
        log "Файлов крупнее ${min_mb} МБ не найдено"
    else
        log "Найдено файлов: $count"
    fi
}

main "$@"
