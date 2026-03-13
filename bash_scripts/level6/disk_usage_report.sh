#!/bin/bash
# Отчёт по использованию диска с записью в лог и конфиг-файлом
# Использование: ./disk_usage_report.sh [-c конфиг] [-o лог] [-t порог%] [-h]

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_CONF="$(dirname "$0")/disk_usage.conf"

# ─── вспомогательные функции ──────────────────────────────────────────────

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    [ -n "${LOGFILE:-}" ] && echo "$msg" >> "$LOGFILE"
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

usage() {
    cat <<EOF
Использование: $SCRIPT_NAME [-c конфиг] [-o лог-файл] [-t порог] [-h]

  -c FILE   конфиг-файл (по умолчанию: disk_usage.conf)
  -o FILE   файл для записи лога (по умолчанию: только stdout)
  -t N      порог заполненности в % для предупреждения (по умолчанию: 80)
  -h        эта справка
EOF
}

load_config() {
    local conf="$1"
    if [ -f "$conf" ]; then
        log "Загружен конфиг: $conf"
        # shellcheck source=/dev/null
        source "$conf"
    fi
}

check_threshold() {
    local mount="$1"
    local used_pct="$2"
    local threshold="$3"

    if [ "$used_pct" -ge "$threshold" ]; then
        log "WARN: $mount использован на ${used_pct}% (порог: ${threshold}%)"
    fi
}

# ─── парсинг аргументов ───────────────────────────────────────────────────

CONF_FILE="$DEFAULT_CONF"
LOGFILE=""
THRESHOLD=80

while getopts "c:o:t:h" opt; do
    case "$opt" in
        c) CONF_FILE="$OPTARG" ;;
        o) LOGFILE="$OPTARG" ;;
        t) THRESHOLD="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# ─── основная логика ──────────────────────────────────────────────────────

main() {
    load_config "$CONF_FILE"

    [ -n "$LOGFILE" ] && log "Лог пишется в: $LOGFILE"

    log "=== Отчёт по дискам (порог предупреждения: ${THRESHOLD}%) ==="
    log ""

    df -h | tail -n +2 | while IFS= read -r line; do
        local mount used_pct
        mount=$(echo "$line" | awk '{print $6}')
        used_pct=$(echo "$line" | awk '{print $5}' | tr -d '%')

        # пропустить tmpfs и devtmpfs
        [[ "$mount" == /dev* || "$mount" == /run* || "$mount" == /sys* || "$mount" == /proc* ]] && continue

        printf "  %-20s %s\n" "$mount" "$line"
        [[ "$used_pct" =~ ^[0-9]+$ ]] && check_threshold "$mount" "$used_pct" "$THRESHOLD"
    done

    log ""
    log "=== Топ-5 крупных директорий в / ==="
    du -sh /* 2>/dev/null | sort -rh | head -5 | while IFS= read -r line; do
        log "  $line"
    done
}

main
