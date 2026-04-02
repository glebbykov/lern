#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml up -d >/dev/null
trap 'docker compose -f lab/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

sleep 3
curl -fsS http://localhost:8087 | grep -qi blue
echo 'verify[1/2]: blue is active — ok'

bash lab/scripts/switch-to-green.sh >/dev/null
sleep 2
curl -fsS http://localhost:8087 | grep -qi green
echo 'verify[2/2]: green switch — ok'

echo 'verify: ok'
