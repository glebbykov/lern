#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml               down -v --remove-orphans >/dev/null 2>&1 || true
docker compose -f lab/02-aliases/compose.yaml    down -v --remove-orphans >/dev/null 2>&1 || true
docker compose -f lab/03-internal-net/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true
docker compose -f broken/compose.yaml            down -v --remove-orphans >/dev/null 2>&1 || true

# Удалить контейнеры из части 6 (EXPOSE vs publish), если остались
docker rm -f test-expose test-publish >/dev/null 2>&1 || true

echo 'cleanup: done'
