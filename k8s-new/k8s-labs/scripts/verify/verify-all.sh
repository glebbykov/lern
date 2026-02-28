#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS=0

run_suite() {
  local pattern="$1"
  for script in $pattern; do
    [[ -f "$script" ]] || continue
    echo "==> running $script"
    if ! bash "$script"; then
      STATUS=1
    fi
    echo
  done
}

run_suite "$ROOT_DIR"/modules/*/verify/verify.sh
run_suite "$ROOT_DIR"/projects/*/verify/verify.sh

exit "$STATUS"
