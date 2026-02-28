#!/usr/bin/env bash
set -euo pipefail

ok() { printf "[OK] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
fail() { printf "[FAIL] %s\n" "$*"; return 1; }

need_bin() {
  command -v "$1" >/dev/null 2>&1 || fail "missing binary: $1"
}

require_namespace() {
  local ns="$1"
  kubectl get ns "$ns" >/dev/null 2>&1 || fail "namespace not found: $ns"
}

require_resource() {
  local ns="$1"
  local kind="$2"
  local name="$3"
  kubectl -n "$ns" get "$kind" "$name" >/dev/null 2>&1 || fail "$kind/$name not found in ns/$ns"
}

require_deployment_ready() {
  local ns="$1"
  local name="$2"
  local timeout="${3:-120s}"
  kubectl -n "$ns" get deploy "$name" >/dev/null 2>&1 || fail "deployment/$name not found in ns/$ns"
  kubectl -n "$ns" rollout status deploy/"$name" --timeout="$timeout" >/dev/null || fail "deployment/$name not ready"
}

require_statefulset_ready() {
  local ns="$1"
  local name="$2"
  kubectl -n "$ns" get sts "$name" >/dev/null 2>&1 || fail "statefulset/$name not found in ns/$ns"
  local ready
  ready=$(kubectl -n "$ns" get sts "$name" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
  [[ "${ready:-0}" -ge 1 ]] || fail "statefulset/$name has no ready replicas"
}

require_service_endpoints() {
  local ns="$1"
  local svc="$2"
  local ep
  ep=$(kubectl -n "$ns" get endpoints "$svc" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)
  [[ -n "$ep" ]] || fail "service/$svc has no ready endpoints in ns/$ns"
}

require_pvc_bound() {
  local ns="$1"
  local pvc="$2"
  local phase
  phase=$(kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "$phase" == "Bound" ]] || fail "pvc/$pvc phase is '$phase', expected 'Bound'"
}
