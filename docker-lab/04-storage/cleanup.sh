#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml down --remove-orphans >/dev/null 2>&1 || true
rm -f lab/backups/*.sql >/dev/null 2>&1 || true
