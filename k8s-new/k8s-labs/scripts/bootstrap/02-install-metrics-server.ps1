$ErrorActionPreference = "Stop"
$manifest = "https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml"

kubectl apply -f $manifest
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s

Write-Host "metrics-server v0.7.2 installed"
