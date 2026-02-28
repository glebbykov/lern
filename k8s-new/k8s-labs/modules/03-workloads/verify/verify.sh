#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab
require_deployment_ready lab workload-demo 120s
require_resource lab svc workload-demo
require_service_endpoints lab workload-demo

if kubectl -n lab get ds node-agent >/dev/null 2>&1; then
  ready=$(kubectl -n lab get ds node-agent -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)
  desired=$(kubectl -n lab get ds node-agent -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)
  [[ "$ready" == "$desired" ]] || fail "daemonset/node-agent ready=$ready desired=$desired"
else
  fail "daemonset/node-agent not found"
fi

ok "module 03 verified"
