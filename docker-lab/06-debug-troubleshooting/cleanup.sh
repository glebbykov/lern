#!/usr/bin/env bash
set -euo pipefail

for f in broken/compose-crashloop.yaml broken/compose-port-conflict.yaml broken/compose-dns.yaml; do
  docker compose -f "$f" down -v --remove-orphans >/dev/null 2>&1 || true
done
