#!/usr/bin/env bash
set -euo pipefail

# 1. Проверить что source-compose.yaml валиден
docker compose -f lab/source-compose.yaml config --quiet 2>/dev/null
echo "verify[1/4]: source-compose.yaml valid — ok"

# 2. Проверить что все manifests существуют
for f in api-deployment api-service api-configmap db-deployment db-service db-secret db-pvc cache-deployment cache-service; do
  [[ -f "lab/manifests/${f}.yaml" ]] || { echo "FAIL: missing lab/manifests/${f}.yaml"; exit 1; }
done
echo "verify[2/4]: all K8s manifests present — ok"

# 3. Проверить что манифесты содержат ключевые поля
grep -q 'readinessProbe' lab/manifests/api-deployment.yaml || { echo "FAIL: api missing readinessProbe"; exit 1; }
grep -q 'livenessProbe' lab/manifests/api-deployment.yaml || { echo "FAIL: api missing livenessProbe"; exit 1; }
grep -q 'secretKeyRef' lab/manifests/api-deployment.yaml || { echo "FAIL: api should ref Secret, not hardcode password"; exit 1; }
echo "verify[3/4]: manifests have probes and secret refs — ok"

# 4. Проверить что broken-сценарии существуют
for f in broken/bad-selector.yaml broken/no-readiness.yaml broken/password-in-configmap.yaml; do
  [[ -f "$f" ]] || { echo "FAIL: missing $f"; exit 1; }
done
echo "verify[4/4]: all broken scenarios present — ok"

echo 'verify: ok'
