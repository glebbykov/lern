#!/usr/bin/env bash
set -euo pipefail

command -v kubectl &>/dev/null || { echo "kubectl not found"; exit 1; }
kubectl cluster-info --request-timeout=5s &>/dev/null || { echo "cluster not reachable"; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

kubectl apply -f "$ROOT_DIR/common/namespaces/lab.yaml"
kubectl apply -f "$ROOT_DIR/common/namespaces/platform.yaml"

echo "Namespaces created/updated: lab, platform"
