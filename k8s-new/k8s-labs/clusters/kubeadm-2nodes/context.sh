#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG_PATH="${1:-./kubeconfig.local}"
export KUBECONFIG="$KUBECONFIG_PATH"

kubectl config get-contexts
kubectl config use-context kubeadm-2nodes-admin
kubectl cluster-info
