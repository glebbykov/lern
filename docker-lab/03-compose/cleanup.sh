#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true
docker compose -f broken/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true
