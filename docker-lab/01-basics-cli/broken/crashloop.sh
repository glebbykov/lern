#!/usr/bin/env bash
set -euo pipefail

docker rm -f cli-crashloop >/dev/null 2>&1 || true
docker run -d --name cli-crashloop --restart always alpine:3.20 sh -c 'echo boom; exit 1'

docker ps -a --filter name=cli-crashloop
