#!/usr/bin/env bash
set -euo pipefail

# --- 1. Named volume: данные переживают перезапуск ---
docker compose -f lab/compose.yaml up -d >/dev/null
trap 'docker compose -f lab/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

docker compose -f lab/compose.yaml exec -T db psql -U appuser -d appdb \
  -c "INSERT INTO notes(text) VALUES ('verify');" >/dev/null

docker compose -f lab/compose.yaml restart db >/dev/null
sleep 3

docker compose -f lab/compose.yaml exec -T db psql -U appuser -d appdb \
  -c "SELECT 1 FROM notes WHERE text='verify';" | grep -q 1
echo 'verify[1/3]: named volume survives restart — ok'

# --- 2. Backup и restore ---
./lab/scripts/backup.sh >/dev/null
docker compose -f lab/compose.yaml exec -T db psql -U appuser -d appdb \
  -c "TRUNCATE TABLE notes;" >/dev/null
./lab/scripts/restore.sh >/dev/null
docker compose -f lab/compose.yaml exec -T db psql -U appuser -d appdb \
  -c "SELECT 1 FROM notes WHERE text='verify';" | grep -q 1
echo 'verify[2/3]: backup/restore — ok'

# --- 3. Volume sharing ---
docker compose -f lab/05-volume-sharing/compose.yaml up -d >/dev/null
sleep 5
docker compose -f lab/05-volume-sharing/compose.yaml exec -T reader \
  sh -c "test -s /data/log.txt"
docker compose -f lab/05-volume-sharing/compose.yaml down -v >/dev/null 2>&1 || true
echo 'verify[3/3]: volume sharing writer→reader — ok'

echo 'verify: all checks passed'
