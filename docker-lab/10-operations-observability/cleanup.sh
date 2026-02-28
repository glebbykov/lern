#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true
