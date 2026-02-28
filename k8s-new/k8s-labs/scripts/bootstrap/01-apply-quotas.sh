#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

kubectl apply -f "$ROOT_DIR/common/quotas/lab-resourcequota.yaml"
kubectl apply -f "$ROOT_DIR/common/quotas/lab-limitrange.yaml"

echo "Quota and LimitRange applied to namespace lab"
