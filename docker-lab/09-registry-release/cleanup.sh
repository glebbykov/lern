#!/usr/bin/env bash
set -euo pipefail

if [ -f compose.yaml ] || [ -f docker-compose.yaml ] || [ -f docker-compose.yml ]; then
  docker compose down -v --remove-orphans || true
fi

# Add module-specific cleanup commands below.
