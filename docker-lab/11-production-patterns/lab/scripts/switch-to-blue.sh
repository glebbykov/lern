#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cp "$LAB_DIR/proxy/blue.conf" "$LAB_DIR/proxy/default.conf"
docker compose -f "$LAB_DIR/compose.yaml" exec -T proxy nginx -t
docker compose -f "$LAB_DIR/compose.yaml" exec -T proxy nginx -s reload

echo 'traffic switched to blue'
