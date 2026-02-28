#!/usr/bin/env bash
set -euo pipefail

MODULE_PATH="${1:-}"
if [[ -z "$MODULE_PATH" ]]; then
  echo "usage: $0 modules/<module-name>"
  exit 1
fi

kubectl -n lab delete -f "$MODULE_PATH/manifests" --ignore-not-found=true || true
kubectl -n lab delete -f "$MODULE_PATH/broken" --ignore-not-found=true || true
kubectl -n lab delete -f "$MODULE_PATH/solutions" --ignore-not-found=true || true

echo "cleaned resources for $MODULE_PATH"
