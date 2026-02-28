#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml up -d >/dev/null
trap 'docker compose -f lab/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

sleep 3
curl -fsS http://localhost:8082 >/dev/null
docker compose -f lab/compose.yaml exec -T toolbox nslookup api >/dev/null
docker compose -f lab/compose.yaml exec -T toolbox nslookup db >/dev/null

echo 'verify: ok'
