#!/usr/bin/env bash
set -euo pipefail

mapfile -t compose_files < <(find . -type f \( -name 'compose.yaml' -o -name 'docker-compose.yaml' -o -name 'docker-compose.yml' \) ! -path './legacy/*' | sort)

if [[ ${#compose_files[@]} -eq 0 ]]; then
  echo "compose validation: no compose files found"
  exit 0
fi

for file in "${compose_files[@]}"; do
  echo "validating $file"
  docker compose -f "$file" config >/dev/null
done

echo "compose validation: ok"
