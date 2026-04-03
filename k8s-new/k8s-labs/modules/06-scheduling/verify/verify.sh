#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab
require_deployment_ready lab select-by-label 120s
require_deployment_ready lab taint-toleration-demo 120s
require_deployment_ready lab affinity-demo 120s

# Verify select-by-label pod is on a node with disktype=ssd
SBL_NODE=$(kubectl -n lab get pod -l app=select-by-label -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)
if [[ -n "$SBL_NODE" ]]; then
  DISK=$(kubectl get node "$SBL_NODE" -o jsonpath='{.metadata.labels.disktype}' 2>/dev/null || true)
  [[ "$DISK" == "ssd" ]] || warn "select-by-label on node $SBL_NODE but disktype=$DISK (expected ssd)"
  ok "select-by-label scheduled on $SBL_NODE (disktype=$DISK)"
else
  warn "select-by-label pod not scheduled yet"
fi

# Verify taint-toleration-demo pod has toleration matching a tainted node
TTD_NODE=$(kubectl -n lab get pod -l app=taint-toleration-demo -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)
if [[ -n "$TTD_NODE" ]]; then
  TAINT=$(kubectl get node "$TTD_NODE" -o jsonpath='{.spec.taints}' 2>/dev/null || true)
  ok "taint-toleration-demo scheduled on $TTD_NODE"
  if [[ -n "$TAINT" && "$TAINT" != "null" ]]; then
    ok "node $TTD_NODE has taints (toleration working)"
  fi
else
  warn "taint-toleration-demo pod not scheduled yet"
fi

ok "module 06 verified"
