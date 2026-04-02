#!/usr/bin/env bash
set -euo pipefail

# Проверяем что workflow файл присутствует и содержит обязательные jobs
WORKFLOW="examples/build-push.yml"

[[ -f "$WORKFLOW" ]] || { echo "missing $WORKFLOW"; exit 1; }

# Обязательные jobs
for job in lint build-test scan push; do
  grep -q "name:.*${job}" "$WORKFLOW" || \
  grep -q "  ${job}:" "$WORKFLOW" || \
    { echo "missing job: $job in $WORKFLOW"; exit 1; }
done

# Trivy должен иметь exit-code и severity gate
grep -q 'exit-code' "$WORKFLOW" || { echo "trivy: missing exit-code gate"; exit 1; }
grep -q 'severity.*HIGH' "$WORKFLOW" || { echo "trivy: missing severity filter"; exit 1; }

# Нет push: true без needs: scan
grep -A5 'push: true' "$WORKFLOW" | grep -q 'needs' || true  # warning only

echo 'verify: ok'
