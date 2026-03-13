#!/usr/bin/env bash
# ==============================================================================
# ШАБЛОН PRODUCTION-READY BASH СКРИПТА
# Копировать этот файл как основу для новых скриптов.
# ==============================================================================
#
# Использование: ./template.sh [ОПЦИИ] <аргументы>
#
# Опции:
#   -d DIR    рабочая директория
#   -o FILE   файл лога
#   -n        dry-run (ничего не делать, только показать)
#   -v        подробный вывод (DEBUG)
#   --version версия скрипта
#   -h        справка

set -euo pipefail
IFS=$'\n\t'

# ─── версия и константы ───────────────────────────────────────────────────

readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOCKFILE="/tmp/${SCRIPT_NAME%.sh}.lock"

# ─── дефолты ──────────────────────────────────────────────────────────────

TARGET_DIR="."
LOGFILE=""
DRY_RUN=false
VERBOSE=false

# ─── логирование ──────────────────────────────────────────────────────────

# Уровни: DEBUG INFO WARN ERROR
_log() {
    local level="$1"; shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    case "$level" in
        ERROR) echo "$msg" >&2 ;;
        DEBUG) $VERBOSE && echo "$msg" || true ;;
        *)     echo "$msg" ;;
    esac
    [ -n "$LOGFILE" ] && echo "$msg" >> "$LOGFILE"
}

log_info()  { _log "INFO"  "$@"; }
log_warn()  { _log "WARN"  "$@"; }
log_error() { _log "ERROR" "$@"; }
log_debug() { _log "DEBUG" "$@"; }

die() {
    log_error "$@"
    exit 1
}

# ─── очистка при любом выходе ─────────────────────────────────────────────

_cleanup() {
    local exit_code=$?
    rm -rf "$LOCKFILE" 2>/dev/null || true
    if [ "$exit_code" -ne 0 ]; then
        log_error "Скрипт завершился с кодом: $exit_code"
    else
        log_info "Завершено успешно"
    fi
}
trap '_cleanup' EXIT

_on_error() {
    local line="$1"
    log_error "Ошибка на строке $line (команда: ${BASH_COMMAND})"
}
trap '_on_error $LINENO' ERR

# ─── lockfile ─────────────────────────────────────────────────────────────

acquire_lock() {
    if ! mkdir "$LOCKFILE" 2>/dev/null; then
        die "Другой экземпляр уже запущен (lock: $LOCKFILE)"
    fi
    log_debug "Lock получен: $LOCKFILE"
}

# ─── проверка зависимостей ────────────────────────────────────────────────

require_commands() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        die "Отсутствуют зависимости: ${missing[*]}"
    fi
}

# ─── справка ──────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
${SCRIPT_NAME} v${VERSION}

Использование: ${SCRIPT_NAME} [ОПЦИИ]

Опции:
  -d DIR    рабочая директория (по умолчанию: текущая)
  -o FILE   файл для записи лога
  -n        dry-run: показать действия без выполнения
  -v        verbose: включить DEBUG-сообщения
  --version показать версию
  -h        эта справка

Коды выхода:
  0  успех
  1  ошибка выполнения
  2  неверные аргументы
  3  отсутствует зависимость
EOF
}

# ─── парсинг аргументов ───────────────────────────────────────────────────

parse_args() {
    # обработка --version и --help до getopts
    for arg in "$@"; do
        case "$arg" in
            --version) echo "${SCRIPT_NAME} v${VERSION}"; exit 0 ;;
            --help)    usage; exit 0 ;;
        esac
    done

    while getopts "d:o:nvh" opt; do
        case "$opt" in
            d) TARGET_DIR="$OPTARG" ;;
            o) LOGFILE="$OPTARG" ;;
            n) DRY_RUN=true ;;
            v) VERBOSE=true ;;
            h) usage; exit 0 ;;
            *) usage; exit 2 ;;
        esac
    done
    shift $(( OPTIND - 1 ))
    # оставшиеся аргументы доступны через "$@"
}

# ─── валидация ────────────────────────────────────────────────────────────

validate() {
    [ -d "$TARGET_DIR" ] || die "Директория не существует: $TARGET_DIR"
    if [ -n "$LOGFILE" ]; then
        touch "$LOGFILE" 2>/dev/null || die "Нет прав на запись в лог: $LOGFILE"
    fi
}

# ─── основная логика ──────────────────────────────────────────────────────

main() {
    parse_args "$@"

    require_commands find awk sort

    validate

    acquire_lock

    log_info "Запуск ${SCRIPT_NAME} v${VERSION}"
    log_info "Директория : $TARGET_DIR"
    log_info "Dry-run    : $DRY_RUN"
    log_debug "Verbose mode включён"

    # === ВАШ КОД ЗДЕСЬ ===
    log_info "Пример: считаем файлы в $TARGET_DIR"
    local count
    count=$(find "$TARGET_DIR" -maxdepth 1 -type f | wc -l)
    log_info "Файлов: $count"
    # =====================
}

main "$@"
