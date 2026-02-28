#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab
require_pvc_bound lab demo-pvc
require_resource lab svc stateful-demo-headless
require_statefulset_ready lab stateful-demo

ok "module 05 verified"
