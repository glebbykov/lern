$ErrorActionPreference = "Continue"
$root = Resolve-Path "$PSScriptRoot/../.."

# Clean modules (lab namespace)
Get-ChildItem "$root/modules" -Directory | ForEach-Object {
  kubectl -n lab delete -f "$($_.FullName)/manifests" --ignore-not-found=true
  kubectl -n lab delete -f "$($_.FullName)/broken" --ignore-not-found=true
  kubectl -n lab delete -f "$($_.FullName)/solutions" --ignore-not-found=true
}

# Clean projects (lab + platform namespaces)
Get-ChildItem "$root/projects" -Directory | ForEach-Object {
  foreach ($ns in @("lab", "platform")) {
    if (Test-Path "$($_.FullName)/manifests") {
      kubectl -n $ns delete -f "$($_.FullName)/manifests" --ignore-not-found=true
    }
    if (Test-Path "$($_.FullName)/broken") {
      kubectl -n $ns delete -f "$($_.FullName)/broken" --ignore-not-found=true
    }
    if (Test-Path "$($_.FullName)/solutions") {
      kubectl -n $ns delete -f "$($_.FullName)/solutions" --ignore-not-found=true
    }
  }
}

Write-Host "cleanup finished (lab + platform namespaces)"
