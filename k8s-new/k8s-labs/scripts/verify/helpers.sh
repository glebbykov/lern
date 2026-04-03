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

# ── New helper functions ──────────────────────────────────────

require_storageclass() {
  local sc="${1:-}"
  if [[ -n "$sc" ]]; then
    kubectl get sc "$sc" >/dev/null 2>&1 || fail "storageclass/$sc not found"
  else
    local count
    count=$(kubectl get sc --no-headers 2>/dev/null | wc -l | tr -d ' ')
    [[ "${count:-0}" -ge 1 ]] || fail "no StorageClass found in cluster"
  fi
}

require_job_complete() {
  local ns="$1"
  local name="$2"
  local timeout="${3:-120}"
  kubectl -n "$ns" get job "$name" >/dev/null 2>&1 || fail "job/$name not found in ns/$ns"
  local succeeded
  # Wait for job to complete (up to timeout seconds)
  for i in $(seq 1 "$timeout"); do
    succeeded=$(kubectl -n "$ns" get job "$name" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)
    [[ "${succeeded:-0}" -ge 1 ]] && return 0
    sleep 1
  done
  fail "job/$name did not complete within ${timeout}s"
}

require_pod_phase() {
  local ns="$1"
  local label="$2"
  local expected="$3"
  local phase
  phase=$(kubectl -n "$ns" get pod -l "$label" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
  [[ "$phase" == "$expected" ]] || fail "pod with label $label phase='$phase', expected='$expected'"
}

require_pod_condition() {
  local ns="$1"
  local pod_name="$2"
  local expected_reason="$3"
  # Check container statuses for the expected reason (OOMKilled, CrashLoopBackOff, ImagePullBackOff, etc.)
  local reason
  reason=$(kubectl -n "$ns" get pod "$pod_name" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)
  [[ "$reason" == "$expected_reason" ]] && return 0
  reason=$(kubectl -n "$ns" get pod "$pod_name" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || true)
  [[ "$reason" == "$expected_reason" ]] && return 0
  fail "pod/$pod_name expected reason='$expected_reason', got waiting.reason or lastState"
}

require_security_context() {
  local ns="$1"
  local kind="$2"
  local name="$3"
  local sc
  sc=$(kubectl -n "$ns" get "$kind" "$name" -o jsonpath='{.spec.template.spec.containers[0].securityContext}' 2>/dev/null || true)
  [[ -n "$sc" && "$sc" != "{}" ]] || fail "$kind/$name has no securityContext"
}
