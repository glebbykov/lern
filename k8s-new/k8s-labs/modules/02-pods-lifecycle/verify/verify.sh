#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab
require_deployment_ready lab probe-demo 120s
require_resource lab svc probe-demo
require_service_endpoints lab probe-demo

if ! kubectl -n lab get pod init-wait-dns >/dev/null 2>&1; then
  warn "init-wait-dns pod is not applied"
fi

ok "module 02 verified"
