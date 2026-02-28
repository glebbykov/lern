$ErrorActionPreference = "Continue"
$root = Resolve-Path "$PSScriptRoot/../.."

Get-ChildItem "$root/modules" -Directory | ForEach-Object {
  kubectl -n lab delete -f "$($_.FullName)/manifests" --ignore-not-found=true
  kubectl -n lab delete -f "$($_.FullName)/broken" --ignore-not-found=true
  kubectl -n lab delete -f "$($_.FullName)/solutions" --ignore-not-found=true
}

Write-Host "cleanup finished"
