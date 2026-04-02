#!/usr/bin/env bash
set -euo pipefail

# 1. Проверить socket-mount compose
docker compose -f lab/socket-mount/compose.yaml config --quiet 2>/dev/null
echo "verify[1/3]: socket-mount compose valid — ok"

# 2. Проверить dind compose
docker compose -f lab/dind/compose.yaml config --quiet 2>/dev/null
echo "verify[2/3]: dind compose valid — ok"

# 3. Проверить что broken-сценарии существуют
for f in broken/compose-no-cli.yaml broken/compose-wrong-perms.yaml broken/compose-dind-no-priv.yaml; do
  [[ -f "$f" ]] || { echo "FAIL: missing $f"; exit 1; }
done
echo "verify[3/3]: all broken scenarios present — ok"

echo 'verify: ok'
