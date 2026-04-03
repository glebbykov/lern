#!/usr/bin/env bash
set -euo pipefail

command -v kubectl &>/dev/null || { echo "kubectl not found"; exit 1; }
kubectl cluster-info --request-timeout=5s &>/dev/null || { echo "cluster not reachable"; exit 1; }

LOCAL_PATH_VERSION="v0.0.26"
MANIFEST_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/${LOCAL_PATH_VERSION}/deploy/local-path-storage.yaml"

kubectl apply -f "$MANIFEST_URL"
kubectl -n local-path-storage rollout status deploy/local-path-provisioner --timeout=120s

# Make local-path the default StorageClass so PVCs bind without storageClassName
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo "local-path-provisioner ${LOCAL_PATH_VERSION} installed and set as default StorageClass"
