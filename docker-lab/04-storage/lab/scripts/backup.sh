#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$LAB_DIR/backups"
outfile="$LAB_DIR/backups/appdb_$(date +%Y%m%d_%H%M%S).sql"

docker compose -f "$LAB_DIR/compose.yaml" exec -T db pg_dump -U appuser appdb > "$outfile"

echo "backup created: $outfile"
