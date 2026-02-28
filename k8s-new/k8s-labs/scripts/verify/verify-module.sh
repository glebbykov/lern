#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_PATH="${1:-}"

if [[ -z "$TARGET_PATH" ]]; then
  echo "usage: $0 modules/<module-name>|projects/<project-name>"
  exit 1
fi

VERIFY_SCRIPT="$ROOT_DIR/$TARGET_PATH/verify/verify.sh"

if [[ ! -f "$VERIFY_SCRIPT" ]]; then
  echo "verify script not found: $VERIFY_SCRIPT"
  exit 1
fi

bash "$VERIFY_SCRIPT"
