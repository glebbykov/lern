#!/usr/bin/env bash
set -euo pipefail

docker build -t dockerlab/simple-web:check ./lab >/dev/null
cid="$(docker run -d -p 18090:8090 dockerlab/simple-web:check)"
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; docker image rm dockerlab/simple-web:check >/dev/null 2>&1 || true' EXIT
sleep 2
curl -fsS http://localhost:18090/healthz >/dev/null

echo 'verify: ok'
