#!/usr/bin/env bash
set -euo pipefail

docker image rm dockerlab/go-api:dev dockerlab/go-api:single >/dev/null 2>&1 || true
