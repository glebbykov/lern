#!/usr/bin/env bash
set -euo pipefail

docker run -d --name cli-nginx -p 8080:80 nginx:1.27-alpine >/dev/null
status="$(docker inspect cli-nginx --format '{{.State.Status}}')"
if [[ "$status" != "running" ]]; then
  echo "container status is $status"
  exit 1
fi
docker rm -f cli-nginx >/dev/null

echo 'verify: ok'
