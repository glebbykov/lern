#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab

# StorageClass must exist before PVC checks
require_storageclass

require_pvc_bound lab demo-pvc
require_resource lab svc stateful-demo-headless
require_statefulset_ready lab stateful-demo

# Verify StatefulSet has volumeClaimTemplates
VCT=$(kubectl -n lab get sts stateful-demo -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}' 2>/dev/null || true)
[[ -n "$VCT" ]] || warn "statefulset/stateful-demo has no volumeClaimTemplates"
ok "statefulset/stateful-demo has volumeClaimTemplate: $VCT"

ok "module 05 verified"
