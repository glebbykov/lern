#!/usr/bin/env bash
set -euo pipefail

# Остановить локальный registry (если запущен из практики)
docker rm -f registry >/dev/null 2>&1 || true

# Удалить образы собранные в этом модуле
docker rmi -f \
  localhost:5000/myapp:1.0.0 \
  localhost:5000/myapp:1.1.0 \
  localhost:5000/myapp:stable \
  localhost:5000/myapp:multiarch \
  >/dev/null 2>&1 || true

# Удалить buildx builder если создавался
docker buildx rm multiarch >/dev/null 2>&1 || true

echo 'cleanup: done'
