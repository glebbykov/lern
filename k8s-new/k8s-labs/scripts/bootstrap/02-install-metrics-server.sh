#!/usr/bin/env bash
set -euo pipefail

command -v kubectl &>/dev/null || { echo "kubectl not found"; exit 1; }
kubectl cluster-info --request-timeout=5s &>/dev/null || { echo "cluster not reachable"; exit 1; }

# Pinned version for reproducible labs
MANIFEST_URL="https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml"

kubectl apply -f "$MANIFEST_URL"
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s

echo "metrics-server v0.7.2 installed"
