#!/usr/bin/env bash
# Показывает: образ больше НЕ содержит секрет, секрет появляется
# только в рантайме по пути /run/secrets/app_secret (tmpfs от Docker).
set -euo pipefail
cd "$(dirname "$0")"

cp ../common/app_file.py app.py
cp ../common/requirements.txt requirements.txt

echo "==> build stage2"
docker compose build

echo "==> up stage2"
docker compose up -d

for _ in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8083/healthz >/dev/null 2>&1; then break; fi
  sleep 0.5
done

echo "==> секрета нет в image metadata (ENV/Config):"
docker image inspect hardening-lab/stage2:latest \
  --format '{{json .Config.Env}}' || true
echo

echo "==> секрета нет в слоях (docker history):"
docker history --no-trunc hardening-lab/stage2:latest | grep -i SECRET || echo "ни одного упоминания — хорошо"

echo "==> секрет примонтирован как tmpfs в /run/secrets:"
docker exec hardening-stage2 sh -c 'mount | grep /run/secrets; ls -l /run/secrets'

echo "==> /secret (должен быть source=file):"
curl -fsS http://127.0.0.1:8083/secret; echo
