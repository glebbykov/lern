#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml            down --remove-orphans -v >/dev/null 2>&1 || true
docker compose -f lab/03-bind-mount/compose.yaml down --remove-orphans    >/dev/null 2>&1 || true
docker compose -f lab/04-tmpfs/compose.yaml       down --remove-orphans    >/dev/null 2>&1 || true
docker compose -f lab/05-volume-sharing/compose.yaml down --remove-orphans -v >/dev/null 2>&1 || true
docker compose -f broken/compose-no-volume.yaml   down --remove-orphans    >/dev/null 2>&1 || true
docker compose -f broken/compose-wrong-bind.yaml  down --remove-orphans    >/dev/null 2>&1 || true

rm -f lab/backups/*.sql >/dev/null 2>&1 || true

echo 'cleanup: done'
