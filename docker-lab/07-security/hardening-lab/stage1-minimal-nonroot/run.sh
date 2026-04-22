#!/usr/bin/env bash
# Собирает stage1: alpine-база + non-root.
# Демонстрирует: размер образа, uid != 0, запись в /app уже запрещена
# (мы не чинили compose, но само приложение пишет только там, где может).
set -euo pipefail
cd "$(dirname "$0")"

cp ../common/app_env.py app.py
cp ../common/requirements.txt requirements.txt

echo "==> build stage1"
docker compose build

echo "==> up stage1"
docker compose up -d

for _ in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8083/healthz >/dev/null 2>&1; then break; fi
  sleep 0.5
done

echo "==> кто я?"
docker exec hardening-stage1 id

echo "==> размеры образов stage0 vs stage1:"
docker image ls --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep hardening-lab || true

echo "==> попытка писать в /etc как не-root (должно упасть Permission denied):"
docker exec hardening-stage1 sh -c 'touch /etc/pwned 2>&1 || echo "ожидаемо: permission denied"'

echo "==> /secret:"
curl -fsS http://127.0.0.1:8083/secret; echo

echo "Готово: мы не root, образ в ~10-20 раз меньше ubuntu:latest."
