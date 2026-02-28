#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml up -d >/dev/null
trap 'docker compose -f lab/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

sleep 3
curl -fsS http://localhost:8087 | grep -qi blue

echo 'verify: ok'
