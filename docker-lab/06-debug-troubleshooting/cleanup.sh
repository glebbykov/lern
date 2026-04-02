#!/usr/bin/env bash
set -euo pipefail

for f in \
  broken/compose-crashloop.yaml \
  broken/compose-port-conflict.yaml \
  broken/compose-dns.yaml \
  broken/compose-oom.yaml \
  broken/compose-healthcheck-fail.yaml \
  broken/compose-readonly-fs.yaml \
  broken/compose-missing-env.yaml \
  broken/compose-wrong-image.yaml \
  broken/compose-volume-perm.yaml
do
  docker compose -f "$f" down -v --remove-orphans >/dev/null 2>&1 || true
done

# Контейнеры из сценария 10 (ручной docker run)
docker rm -f dbg-listen mem-check pg-test >/dev/null 2>&1 || true

echo 'cleanup: done'
