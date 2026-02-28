#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab
require_deployment_ready lab net-demo 120s
require_resource lab svc net-demo
require_service_endpoints lab net-demo

if kubectl -n lab get ingress net-demo >/dev/null 2>&1; then
  ok "ingress/net-demo exists"
else
  warn "ingress/net-demo is not applied"
fi

ok "module 04 verified"
