#!/usr/bin/env bash
set -euo pipefail

command -v kubectl &>/dev/null || { echo "kubectl not found"; exit 1; }
kubectl cluster-info --request-timeout=5s &>/dev/null || { echo "cluster not reachable"; exit 1; }

# Pinned ingress-nginx release for reproducible labs
MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.5/deploy/static/provider/cloud/deploy.yaml"

kubectl apply -f "$MANIFEST_URL"
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s

echo "ingress-nginx controller-v1.11.5 installed"
