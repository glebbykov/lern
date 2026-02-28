$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot/../.."

kubectl apply -f "$root/common/profiles/2gb/metrics-server-patch.yaml"
kubectl apply -f "$root/common/profiles/2gb/ingress-nginx-controller-patch.yaml"

Write-Host "2GB profile resources applied for metrics-server and ingress-nginx controller"
