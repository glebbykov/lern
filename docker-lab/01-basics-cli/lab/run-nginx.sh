#!/usr/bin/env bash
set -euo pipefail

docker rm -f cli-nginx >/dev/null 2>&1 || true
docker run -d --name cli-nginx -p 8080:80 --restart unless-stopped nginx:1.27-alpine

echo 'open http://localhost:8080'
