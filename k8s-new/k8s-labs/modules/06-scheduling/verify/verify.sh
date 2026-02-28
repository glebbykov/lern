#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
require_namespace lab
require_deployment_ready lab select-by-label 120s
require_deployment_ready lab taint-toleration-demo 120s
require_deployment_ready lab affinity-demo 120s

ok "module 06 verified"
