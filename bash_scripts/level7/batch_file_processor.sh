#!/usr/bin/env bash
# ==============================================================================
# Параллельная обработка файлов с полным набором production-практик
#
# Задача: найти все файлы по паттерну, посчитать строки в каждом,
#         сохранить отчёт. Обрабатывать параллельно (N воркеров).
#
# Использование: ./batch_file_processor.sh -d <директория> [-p <паттерн>]
#                [-w <воркеры>] [-o <отчёт>] [-n] [-v] [-h]
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

readonly VERSION="1.2.0"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly LOCKFILE="/tmp/${SCRIPT_NAME%.sh}.lock"

# ─── дефолты ──────────────────────────────────────────────────────────────

TARGET_DIR="."
FILE_PATTERN="*.sh"
WORKERS=4
REPORT_FILE=""
DRY_RUN=false
VERBOSE=false

# ─── логирование ──────────────────────────────────────────────────────────

_log() {
    local level="$1"; shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    case "$level" in
        ERROR) echo "$msg" >&2 ;;
        DEBUG) $VERBOSE && echo "$msg" || true ;;
        *)     echo "$msg" ;;
    esac
    [ -n "${REPORT_FILE:-}" ] && echo "$msg" >> "$REPORT_FILE"
}
log_info()  { _log "INFO"  "$@"; }
log_warn()  { _log "WARN"  "$@"; }
log_error() { _log "ERROR" "$@"; }
log_debug() { _log "DEBUG" "$@"; }

die() { log_error "$@"; exit 1; }

# ─── очистка ──────────────────────────────────────────────────────────────

_cleanup() {
    local code=$?
    rm -rf "$LOCKFILE" 2>/dev/null || true
    # завершить все фоновые дочерние процессы
    jobs -p | xargs -r kill 2>/dev/null || true
    [ "$code" -ne 0 ] && log_error "Аварийное завершение (код: $code)"
}
trap '_cleanup' EXIT
trap 'log_warn "Прерван сигналом (SIGINT)"; exit 130' INT
trap 'log_warn "Прерван сигналом (SIGTERM)"; exit 143' TERM

# ─── lockfile ─────────────────────────────────────────────────────────────

acquire_lock() {
    mkdir "$LOCKFILE" 2>/dev/null || die "Уже запущен (lock: $LOCKFILE)"
}

# ─── справка ──────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
${SCRIPT_NAME} v${VERSION} — параллельная обработка файлов

Использование: ${SCRIPT_NAME} [ОПЦИИ]

  -d DIR    директория для поиска файлов (по умолчанию: текущая)
  -p PAT    паттерн файлов, напр. "*.log" (по умолчанию: *.sh)
  -w N      число параллельных воркеров (по умолчанию: 4)
  -o FILE   файл отчёта (по умолчанию: только stdout)
  -n        dry-run: показать файлы, не обрабатывать
  -v        verbose режим
  --version версия
  -h        справка
EOF
}

# ─── парсинг аргументов ───────────────────────────────────────────────────

for arg in "$@"; do
    case "$arg" in
        --version) echo "${SCRIPT_NAME} v${VERSION}"; exit 0 ;;
        --help)    usage; exit 0 ;;
    esac
done

while getopts "d:p:w:o:nvh" opt; do
    case "$opt" in
        d) TARGET_DIR="$OPTARG" ;;
        p) FILE_PATTERN="$OPTARG" ;;
        w) WORKERS="$OPTARG" ;;
        o) REPORT_FILE="$OPTARG" ;;
        n) DRY_RUN=true ;;
        v) VERBOSE=true ;;
        h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

# ─── валидация ────────────────────────────────────────────────────────────

[ -d "$TARGET_DIR" ] || die "Директория не существует: $TARGET_DIR"
[[ "$WORKERS" =~ ^[1-9][0-9]*$ ]] || die "Число воркеров должно быть положительным числом"
[ -n "$REPORT_FILE" ] && touch "$REPORT_FILE" 2>/dev/null || true

# ─── обработка одного файла (запускается в фоне) ──────────────────────────

process_file() {
    local file="$1"
    local lines
    lines=$(wc -l < "$file" 2>/dev/null) || { echo "ERROR $file"; return 1; }
    printf "%-6d  %s\n" "$lines" "$file"
}
export -f process_file

# ─── основная логика ──────────────────────────────────────────────────────

main() {
    acquire_lock

    log_info "${SCRIPT_NAME} v${VERSION}"
    log_info "Директория : $TARGET_DIR"
    log_info "Паттерн    : $FILE_PATTERN"
    log_info "Воркеры    : $WORKERS"
    log_info "Dry-run    : $DRY_RUN"

    # собрать список файлов
    mapfile -t files < <(find "$TARGET_DIR" -type f -name "$FILE_PATTERN" | sort)

    local total="${#files[@]}"
    log_info "Найдено файлов: $total"

    if [ "$total" -eq 0 ]; then
        log_warn "Файлы по паттерну '$FILE_PATTERN' не найдены"
        exit 0
    fi

    if $DRY_RUN; then
        log_info "[DRY-RUN] Будут обработаны:"
        printf '  %s\n' "${files[@]}"
        exit 0
    fi

    # параллельная обработка через xargs
    log_info "---"
    printf '%s\n' "${files[@]}" \
        | xargs -P "$WORKERS" -I{} bash -c 'process_file "$@"' _ {} \
        | sort -k1 -rn \
        | while IFS= read -r line; do
            log_info "$line"
          done

    log_info "---"
    log_info "Обработка завершена. Файлов: $total"
}

main
