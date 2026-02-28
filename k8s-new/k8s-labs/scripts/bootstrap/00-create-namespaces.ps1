$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot/../.."

kubectl apply -f "$root/common/namespaces/lab.yaml"
kubectl apply -f "$root/common/namespaces/platform.yaml"

Write-Host "Namespaces created/updated: lab, platform"
