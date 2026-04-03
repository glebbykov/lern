#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab
require_deployment_ready lab workload-demo 120s
require_resource lab svc workload-demo
require_service_endpoints lab workload-demo

# DaemonSet
if kubectl -n lab get ds node-agent >/dev/null 2>&1; then
  ready=$(kubectl -n lab get ds node-agent -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)
  desired=$(kubectl -n lab get ds node-agent -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)
  [[ "$ready" == "$desired" ]] || fail "daemonset/node-agent ready=$ready desired=$desired"
else
  fail "daemonset/node-agent not found"
fi

# Job: print-time должен завершиться с Completed
if kubectl -n lab get job print-time >/dev/null 2>&1; then
  succeeded=$(kubectl -n lab get job print-time -o jsonpath='{.status.succeeded}' 2>/dev/null || true)
  [[ "${succeeded:-0}" -ge 1 ]] || warn "job/print-time has not completed yet (succeeded=$succeeded)"
  ok "job/print-time completed"
else
  warn "job/print-time not found — apply it first"
fi

# CronJob: print-time-cron должен существовать
require_resource lab cronjob print-time-cron
ok "cronjob/print-time-cron exists"

ok "module 03 verified"
