#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 1
  fi
}

require_cmd hadolint
require_cmd yamllint
require_cmd shellcheck

mapfile -t dockerfiles < <(find . -type f \( -name 'Dockerfile' -o -name 'Dockerfile.*' -o -name '*.Dockerfile' \) ! -path './legacy/*' | sort)
mapfile -t yaml_files < <(find . -type f \( -name '*.yaml' -o -name '*.yml' \) ! -path './legacy/*' | sort)
mapfile -t sh_files < <(find . -type f -name '*.sh' ! -path './legacy/*' | sort)

if [[ ${#dockerfiles[@]} -gt 0 ]]; then
  hadolint "${dockerfiles[@]}"
else
  echo "hadolint: no Dockerfiles found"
fi

if [[ ${#yaml_files[@]} -gt 0 ]]; then
  yamllint -c .yamllint.yml "${yaml_files[@]}"
else
  echo "yamllint: no YAML files found"
fi

if [[ ${#sh_files[@]} -gt 0 ]]; then
  shellcheck "${sh_files[@]}"
else
  echo "shellcheck: no shell scripts found"
fi
