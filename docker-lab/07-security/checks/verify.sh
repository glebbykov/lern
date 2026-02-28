#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml up -d --build >/dev/null
trap 'docker compose -f lab/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

user="$(docker inspect security-app --format '{{.Config.User}}')"
readonly="$(docker inspect security-app --format '{{.HostConfig.ReadonlyRootfs}}')"

if [[ -z "$user" || "$user" == "root" ]]; then
  echo 'container runs as root'
  exit 1
fi

if [[ "$readonly" != "true" ]]; then
  echo 'readonly rootfs is not enabled'
  exit 1
fi

echo 'verify: ok'
