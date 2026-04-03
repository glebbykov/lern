#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab

# Verify solutions exist in repository
[[ -f "$ROOT_DIR/projects/project-c-broken-cluster-lab/solutions/crashloop-fixed.yaml" ]] || fail "missing crashloop solution"
[[ -f "$ROOT_DIR/projects/project-c-broken-cluster-lab/solutions/readiness-fixed.yaml" ]] || fail "missing readiness solution"
[[ -f "$ROOT_DIR/projects/project-c-broken-cluster-lab/solutions/imagepullbackoff-fixed.yaml" ]] || fail "missing imagepull solution"
[[ -f "$ROOT_DIR/projects/project-c-broken-cluster-lab/solutions/oomkilled-fixed.yaml" ]] || fail "missing oom solution"

# Verify broken pods are in expected failure states (if deployed)
check_broken_pod() {
  local pod="$1"
  local expected="$2"
  if kubectl -n lab get pod "$pod" >/dev/null 2>&1; then
    # Check waiting reason
    local reason
    reason=$(kubectl -n lab get pod "$pod" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)
    if [[ "$reason" == "$expected" ]]; then
      ok "broken pod $pod is in expected state: $expected"
      return 0
    fi
    # Check last terminated reason
    reason=$(kubectl -n lab get pod "$pod" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || true)
    if [[ "$reason" == "$expected" ]]; then
      ok "broken pod $pod has lastState: $expected"
      return 0
    fi
    warn "broken pod $pod present but state='$reason', expected='$expected'"
  else
    warn "broken pod $pod not deployed yet (expected — deploy it to test troubleshooting)"
  fi
}

check_broken_pod "crashloop-app"     "CrashLoopBackOff"
check_broken_pod "imagepull-app"     "ImagePullBackOff"
check_broken_pod "oom-app"           "OOMKilled"

ok "project C verify script executed"
