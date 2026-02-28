#!/usr/bin/env bash
set -euo pipefail

mapfile -t cleanup_scripts < <(find . -mindepth 2 -maxdepth 2 -type f -name 'cleanup.sh' ! -path './legacy/*' | sort)

if [[ ${#cleanup_scripts[@]} -eq 0 ]]; then
  echo "cleanup: no module cleanup scripts found"
  exit 0
fi

for script in "${cleanup_scripts[@]}"; do
  dir="$(dirname "$script")"
  echo "cleanup $dir"
  (cd "$dir" && bash ./cleanup.sh)
done

echo "cleanup: done"
