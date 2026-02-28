$ErrorActionPreference = "Stop"

docker version
docker compose version
docker run --rm hello-world | Out-Null
Write-Host "environment check: ok"
