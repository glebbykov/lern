#!/usr/bin/env bash
set -euo pipefail

for f in lab/web-db-cache/spec.md lab/event-driven/spec.md lab/security-first/spec.md; do
  [[ -f "$f" ]] || { echo "missing $f"; exit 1; }
done

echo 'verify: capstone specs present'
