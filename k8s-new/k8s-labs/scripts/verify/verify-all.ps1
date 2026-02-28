$ErrorActionPreference = "Continue"
$root = Resolve-Path "$PSScriptRoot/../.."
$status = 0

$targets = @()
$targets += Get-ChildItem "$root/modules" -Directory | ForEach-Object { Join-Path $_.FullName "verify/verify.sh" }
$targets += Get-ChildItem "$root/projects" -Directory | ForEach-Object { Join-Path $_.FullName "verify/verify.sh" }

foreach ($t in $targets) {
  if (-not (Test-Path $t)) { continue }
  Write-Host "==> running $t"
  bash $t
  if ($LASTEXITCODE -ne 0) { $status = 1 }
  Write-Host ""
}

exit $status
