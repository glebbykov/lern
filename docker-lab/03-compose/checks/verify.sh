#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml up -d --build >/dev/null
trap 'docker compose -f lab/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

sleep 5
curl -fsS http://localhost:8081/healthz >/dev/null
curl -fsS http://localhost:8081/db-check >/dev/null

echo 'verify: ok'
