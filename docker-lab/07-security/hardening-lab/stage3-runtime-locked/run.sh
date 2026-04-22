#!/usr/bin/env bash
# Собирает и поднимает полностью захардененный контейнер.
# После этого проверяем, что приложение всё ещё работает.
set -euo pipefail
cd "$(dirname "$0")"

cp ../common/app_file.py app.py
cp ../common/requirements.txt requirements.txt

echo "==> build stage3"
docker compose build

echo "==> up stage3 (read_only + cap_drop + no-new-privileges + лимиты)"
docker compose up -d

for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8083/healthz >/dev/null 2>&1; then break; fi
  sleep 0.5
done

echo "==> healthz (убеждаемся, что приложение живо):"
curl -fsS http://127.0.0.1:8083/healthz; echo

echo "==> запись в /tmp (tmpfs) — должно ПРОЙТИ:"
curl -fsS -X POST http://127.0.0.1:8083/log \
  -H 'content-type: application/json' \
  -d '{"msg":"hello from stage3"}'
echo

echo "==> capabilities должны быть пустые (CapEff=0000000000000000):"
docker exec hardening-stage3 sh -c 'grep CapEff /proc/1/status'

echo "==> inspect: read_only=true, security opts:"
docker inspect hardening-stage3 --format 'ReadOnly={{.HostConfig.ReadonlyRootfs}}  SecOpts={{.HostConfig.SecurityOpt}}  CapDrop={{.HostConfig.CapDrop}}  Mem={{.HostConfig.Memory}}  PIDs={{.HostConfig.PidsLimit}}'

echo
echo "Stage3 готов — переходи к stage4 (breakin checks)."
