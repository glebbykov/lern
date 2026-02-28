#!/usr/bin/env bash
set -euo pipefail

docker version >/dev/null
docker compose version >/dev/null
docker run --rm hello-world >/dev/null

echo 'verify: ok'
