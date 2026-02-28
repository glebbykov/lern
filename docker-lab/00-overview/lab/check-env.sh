#!/usr/bin/env bash
set -euo pipefail

echo '== docker version =='
docker version

echo '== docker compose version =='
docker compose version

echo '== hello-world =='
docker run --rm hello-world >/dev/null

echo 'environment check: ok'
