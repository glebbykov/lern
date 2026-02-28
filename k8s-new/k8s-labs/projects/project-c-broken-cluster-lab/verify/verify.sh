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

ok "project C verify script executed"
