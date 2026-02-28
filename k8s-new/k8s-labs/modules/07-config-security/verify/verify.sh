#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab
require_resource lab sa pod-reader

can_get=$(kubectl -n lab auth can-i get pods --as=system:serviceaccount:lab:pod-reader)
[[ "$can_get" == "yes" ]] || fail "serviceaccount pod-reader cannot get pods"

can_delete=$(kubectl -n lab auth can-i delete pods --as=system:serviceaccount:lab:pod-reader)
[[ "$can_delete" == "no" ]] || fail "serviceaccount pod-reader should not delete pods"

ok "module 07 verified"
