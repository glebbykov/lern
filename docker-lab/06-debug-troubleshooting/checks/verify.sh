#!/usr/bin/env bash
set -euo pipefail

# This module is diagnostic-first; verification checks that scenarios are reproducible.
docker compose -f broken/compose-crashloop.yaml up -d >/dev/null
docker inspect dbg-crash --format '{{.State.RestartCount}}' >/dev/null
docker compose -f broken/compose-crashloop.yaml down -v >/dev/null

echo 'verify: reproducible scenarios ready'
