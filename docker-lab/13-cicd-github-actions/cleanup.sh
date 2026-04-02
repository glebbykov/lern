#!/usr/bin/env bash
set -euo pipefail

# Образы собранные в практике
docker rmi -f myapp:ci myapp:test >/dev/null 2>&1 || true

# Локальный registry (если запускался для multi-platform практики)
docker rm -f registry >/dev/null 2>&1 || true

# Buildx builder
docker buildx rm multiarch >/dev/null 2>&1 || true

echo 'cleanup: done'
