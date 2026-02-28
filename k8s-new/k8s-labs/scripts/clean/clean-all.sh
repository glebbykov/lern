#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for module in "$ROOT_DIR"/modules/*; do
  [[ -d "$module" ]] || continue
  kubectl -n lab delete -f "$module/manifests" --ignore-not-found=true || true
  kubectl -n lab delete -f "$module/broken" --ignore-not-found=true || true
  kubectl -n lab delete -f "$module/solutions" --ignore-not-found=true || true
 done

echo "cleanup finished"
