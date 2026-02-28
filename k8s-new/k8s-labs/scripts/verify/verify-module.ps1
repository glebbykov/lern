param(
  [Parameter(Mandatory = $true)]
  [string]$TargetPath
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot/../.."
$script = Join-Path $root "$TargetPath/verify/verify.sh"

if (-not (Test-Path $script)) {
  throw "verify script not found: $script"
}

bash $script
