#!/usr/bin/env bash
set -euo pipefail

docker rm -f cli-nginx cli-crashloop >/dev/null 2>&1 || true
