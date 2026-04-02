#!/usr/bin/env bash
set -euo pipefail

docker rmi -f dockerlab/init-bad:dev dockerlab/init-bad:test >/dev/null 2>&1 || true
docker rmi -f dockerlab/init-go:dev dockerlab/init-python:dev dockerlab/init-node:dev >/dev/null 2>&1 || true

echo 'cleanup: done'
