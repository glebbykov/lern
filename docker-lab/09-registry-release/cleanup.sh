#!/usr/bin/env bash
set -euo pipefail

# Keep remote images untouched; only local cleanup.
docker image prune -f >/dev/null 2>&1 || true
