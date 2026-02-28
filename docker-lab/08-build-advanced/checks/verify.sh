#!/usr/bin/env bash
set -euo pipefail

docker build -t dockerlab/go-api:dev ./lab >/dev/null
cid="$(docker run -d -p 18084:8084 dockerlab/go-api:dev)"
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; docker image rm dockerlab/go-api:dev >/dev/null 2>&1 || true' EXIT

sleep 2
curl -fsS http://localhost:18084/healthz >/dev/null

echo 'verify: ok'
