#!/usr/bin/env bash
set -euo pipefail

command -v kubectl &>/dev/null || { echo "kubectl not found"; exit 1; }
kubectl cluster-info --request-timeout=5s &>/dev/null || { echo "cluster not reachable"; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# kubectl apply -f не работает с patch-файлами (не полный манифест, нет selector/labels).
# Используем kubectl patch --patch-file --type=strategic-merge.
kubectl patch deployment metrics-server -n kube-system \
  --patch-file "$ROOT_DIR/common/profiles/2gb/metrics-server-patch.yaml" \
  --type=strategic-merge

kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --patch-file "$ROOT_DIR/common/profiles/2gb/ingress-nginx-controller-patch.yaml" \
  --type=strategic-merge

echo "2GB profile applied: metrics-server and ingress-nginx-controller patched"
