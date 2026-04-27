# Общие функции для run.sh / check.sh всех этапов.
# source-ить так: . "$(dirname "$0")/../scripts/lib.sh"

set -u

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Этому скрипту нужен root (sudo)." >&2
  exit 1
fi

C_RESET=$'\033[0m'
C_RED=$'\033[31m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_BLUE=$'\033[34m'
C_DIM=$'\033[2m'

# log "сообщение"
log() { printf '%s==>%s %s\n' "${C_BLUE}" "${C_RESET}" "$*"; }
note() { printf '   %s%s%s\n' "${C_DIM}" "$*" "${C_RESET}"; }

PASS=0
FAIL=0

# assert <description> <expression that should succeed>
assert() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '%s ✓ %s%s\n' "${C_GREEN}" "${desc}" "${C_RESET}"
    PASS=$((PASS+1))
  else
    printf '%s ✗ %s%s\n' "${C_RED}" "${desc}" "${C_RESET}"
    FAIL=$((FAIL+1))
  fi
}

# assert_fail <description> <expression that MUST fail>
assert_fail() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '%s ✗ %s (команда прошла, ожидался отказ)%s\n' "${C_RED}" "${desc}" "${C_RESET}"
    FAIL=$((FAIL+1))
  else
    printf '%s ✓ %s (ожидаемый отказ)%s\n' "${C_GREEN}" "${desc}" "${C_RESET}"
    PASS=$((PASS+1))
  fi
}

# summary; вызывать в конце check.sh
summary() {
  echo
  if [[ $FAIL -eq 0 ]]; then
    printf '%s=== итог: %d/%d PASS ===%s\n' "${C_GREEN}" "${PASS}" "$((PASS+FAIL))" "${C_RESET}"
    exit 0
  else
    printf '%s=== итог: %d PASS, %d FAIL ===%s\n' "${C_RED}" "${PASS}" "${FAIL}" "${C_RESET}"
    exit 1
  fi
}

# pause "press enter when ready"  (skipped if NONINTERACTIVE=1)
pause() {
  if [[ "${NONINTERACTIVE:-0}" = "1" ]]; then return; fi
  read -r -p "[нажмите Enter] $*"
}

# require <command> [<command> ...]   — fail if any tool missing
require() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '%sНе установлены: %s%s\n' "${C_RED}" "${missing[*]}" "${C_RESET}" >&2
    printf 'Запусти: sudo ./00-setup/install.sh\n' >&2
    exit 1
  fi
}

# info <description> <expression>  — мягкая проверка, печатается, не считается в FAIL
info() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '%s ℹ %s: есть%s\n' "${C_BLUE}" "${desc}" "${C_RESET}"
  else
    printf '%s ℹ %s: нет (опционально)%s\n' "${C_YELLOW}" "${desc}" "${C_RESET}"
  fi
}
