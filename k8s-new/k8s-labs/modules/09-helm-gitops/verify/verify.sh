#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/verify/helpers.sh"

need_bin kubectl
CHART_DIR="$ROOT_DIR/modules/09-helm-gitops/charts/demo-app"

if command -v helm >/dev/null 2>&1; then
  helm lint "$CHART_DIR"
  helm template demo-app "$CHART_DIR" >/dev/null
else
  warn "helm not installed, skip helm checks"
fi

kubectl apply --dry-run=client -f "$ROOT_DIR/modules/09-helm-gitops/gitops/argocd/project.yaml" >/dev/null
kubectl apply --dry-run=client -f "$ROOT_DIR/modules/09-helm-gitops/gitops/argocd/app.yaml" >/dev/null

ok "module 09 verified"
