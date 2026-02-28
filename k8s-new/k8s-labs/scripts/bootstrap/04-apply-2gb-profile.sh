#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

kubectl apply -f "$ROOT_DIR/common/profiles/2gb/metrics-server-patch.yaml"
kubectl apply -f "$ROOT_DIR/common/profiles/2gb/ingress-nginx-controller-patch.yaml"

echo "2GB profile resources applied for metrics-server and ingress-nginx controller"
