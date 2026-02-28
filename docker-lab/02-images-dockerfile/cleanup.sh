#!/usr/bin/env bash
set -euo pipefail

docker image rm dockerlab/simple-web:dev >/dev/null 2>&1 || true
