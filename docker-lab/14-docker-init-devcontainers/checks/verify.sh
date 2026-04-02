#!/usr/bin/env bash
set -euo pipefail

# 1. Проверить что broken Dockerfile собирается, но запускает от root
docker build -t dockerlab/init-bad:test ./broken >/dev/null 2>&1
user="$(docker run --rm dockerlab/init-bad:test id -u)"
if [[ "$user" == "0" ]]; then
  echo "verify[1/3]: broken Dockerfile runs as root (uid=$user) — expected"
else
  echo "FAIL: broken Dockerfile unexpectedly runs as non-root"
  exit 1
fi

# 2. Проверить что lab/python-app/Dockerfile.fixed существует и содержит USER
if ! grep -q 'USER' lab/python-app/Dockerfile.fixed; then
  echo "FAIL: Dockerfile.fixed missing USER directive"
  exit 1
fi
echo "verify[2/3]: fixed Dockerfile has USER directive — ok"

# 3. Проверить что go-app имеет go.mod
if [[ ! -f "lab/go-app/go.mod" ]]; then
  echo "FAIL: lab/go-app/go.mod missing"
  exit 1
fi
echo "verify[3/3]: go-app has go.mod — ok"

# Cleanup
docker rmi dockerlab/init-bad:test >/dev/null 2>&1 || true

echo 'verify: ok'
