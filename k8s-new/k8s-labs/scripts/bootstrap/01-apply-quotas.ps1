$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot/../.."

kubectl apply -f "$root/common/quotas/lab-resourcequota.yaml"
kubectl apply -f "$root/common/quotas/lab-limitrange.yaml"

Write-Host "Quota and LimitRange applied to namespace lab"
