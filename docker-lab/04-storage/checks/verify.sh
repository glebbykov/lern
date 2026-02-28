#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml up -d >/dev/null
trap 'docker compose -f lab/compose.yaml down --remove-orphans >/dev/null 2>&1 || true' EXIT

docker compose -f lab/compose.yaml exec -T db psql -U appuser -d appdb -c "INSERT INTO notes(text) VALUES ('verify');" >/dev/null
docker compose -f lab/compose.yaml exec -T db psql -U appuser -d appdb -c "SELECT 1 FROM notes WHERE text='verify';" | grep -q 1

echo 'verify: ok'
