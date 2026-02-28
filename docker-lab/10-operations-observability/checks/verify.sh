#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml up -d >/dev/null
trap 'docker compose -f lab/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

sleep 5
curl -fsS http://localhost:8085 >/dev/null
curl -fsS http://localhost:8086/metrics >/dev/null
curl -fsS http://localhost:9090/-/healthy >/dev/null

echo 'verify: ok'
