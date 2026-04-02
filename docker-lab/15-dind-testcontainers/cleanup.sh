#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/socket-mount/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true
docker compose -f lab/dind/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true
docker compose -f broken/compose-no-cli.yaml down -v --remove-orphans >/dev/null 2>&1 || true
docker compose -f broken/compose-wrong-perms.yaml down -v --remove-orphans >/dev/null 2>&1 || true
docker compose -f broken/compose-dind-no-priv.yaml down -v --remove-orphans >/dev/null 2>&1 || true

docker rmi -f test-from-ci internal-app >/dev/null 2>&1 || true

echo 'cleanup: done'
