param(
  [Parameter(Mandatory = $true)]
  [string]$ModulePath
)

$ErrorActionPreference = "Stop"

kubectl -n lab delete -f "$ModulePath/manifests" --ignore-not-found=true
kubectl -n lab delete -f "$ModulePath/broken" --ignore-not-found=true
kubectl -n lab delete -f "$ModulePath/solutions" --ignore-not-found=true

Write-Host "cleaned resources for $ModulePath"
