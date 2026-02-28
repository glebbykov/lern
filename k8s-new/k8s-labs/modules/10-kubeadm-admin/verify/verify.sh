#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
kubectl get nodes >/dev/null || fail "cannot list nodes"
kubectl -n kube-system get pods >/dev/null || fail "cannot list kube-system pods"
kubectl -n kube-system get deploy coredns >/dev/null || warn "coredns deployment not found"

ok "module 10 baseline checks passed"
