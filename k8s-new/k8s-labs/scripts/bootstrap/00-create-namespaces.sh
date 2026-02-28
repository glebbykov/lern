#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

kubectl apply -f "$ROOT_DIR/common/namespaces/lab.yaml"
kubectl apply -f "$ROOT_DIR/common/namespaces/platform.yaml"

echo "Namespaces created/updated: lab, platform"
