#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab
require_deployment_ready lab obs-demo 120s

POD=$(kubectl -n lab get pod -l app=obs-demo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[[ -n "$POD" ]] || fail "obs-demo pod not found"

LINES=$(kubectl -n lab logs "$POD" --tail=3 2>/dev/null | wc -l | tr -d ' ')
[[ "${LINES:-0}" -ge 1 ]] || fail "obs-demo has no logs"

# Verify log format: should contain 'level=' for structured logging
SAMPLE=$(kubectl -n lab logs "$POD" --tail=1 2>/dev/null || true)
if echo "$SAMPLE" | grep -q 'level='; then
  ok "obs-demo logs are structured (contain 'level=')"
else
  warn "obs-demo logs may not be structured: $SAMPLE"
fi

ok "module 08 verified"
