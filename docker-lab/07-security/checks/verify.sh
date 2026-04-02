#!/usr/bin/env bash
set -euo pipefail

docker compose -f lab/compose.yaml up -d --build >/dev/null
trap 'docker compose -f lab/compose.yaml down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

# 1. Non-root user
user="$(docker inspect security-app --format '{{.Config.User}}')"
if [[ -z "$user" || "$user" == "root" ]]; then
  echo "FAIL: container runs as root (user='$user')"
  exit 1
fi
echo "verify[1/4]: non-root user ($user) — ok"

# 2. Read-only rootfs
readonly="$(docker inspect security-app --format '{{.HostConfig.ReadonlyRootfs}}')"
if [[ "$readonly" != "true" ]]; then
  echo 'FAIL: readonly rootfs is not enabled'
  exit 1
fi
echo 'verify[2/4]: readonly rootfs — ok'

# 3. cap_drop: ALL
capdrop="$(docker inspect security-app --format '{{.HostConfig.CapDrop}}')"
if [[ "$capdrop" != "[ALL]" ]]; then
  echo "FAIL: cap_drop expected [ALL], got '$capdrop'"
  exit 1
fi
echo 'verify[3/4]: cap_drop ALL — ok'

# 4. no-new-privileges
secopts="$(docker inspect security-app --format '{{.HostConfig.SecurityOpt}}')"
if [[ "$secopts" != *"no-new-privileges"* ]]; then
  echo "FAIL: no-new-privileges not set (got '$secopts')"
  exit 1
fi
echo 'verify[4/4]: no-new-privileges — ok'

echo 'verify: ok'
