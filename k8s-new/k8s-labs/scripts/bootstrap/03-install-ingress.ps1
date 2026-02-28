$ErrorActionPreference = "Stop"
$manifest = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.5/deploy/static/provider/cloud/deploy.yaml"

kubectl apply -f $manifest
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s

Write-Host "ingress-nginx controller-v1.11.5 installed"
