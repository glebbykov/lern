#!/usr/bin/env bash
# Прогоняет всю лабу подряд, останавливая контейнер между этапами.
set -euo pipefail
cd "$(dirname "$0")"

down_if_up() {
  local dir="$1"
  if [[ -f "$dir/compose.yaml" ]]; then
    (cd "$dir" && docker compose down -v 2>/dev/null || true)
  fi
}

cleanup() {
  down_if_up stage0-antipattern
  down_if_up stage1-minimal-nonroot
  down_if_up stage2-secrets
  down_if_up stage3-runtime-locked
}
trap cleanup EXIT

for s in stage0-antipattern stage1-minimal-nonroot stage2-secrets stage3-runtime-locked; do
  echo
  echo "############################################"
  echo "## $s"
  echo "############################################"
  (cd "$s" && ./run.sh)
  # Между этапами останавливаем контейнер, чтобы порт 8083 освободился.
  (cd "$s" && docker compose down >/dev/null 2>&1 || true)
done

# stage3 уже down; поднимаем снова для stage4.
(cd stage3-runtime-locked && docker compose up -d)
sleep 2
(cd stage4-breakin-checks && ./run.sh)

(cd stage5-scan && ./run.sh)
