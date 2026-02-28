#!/usr/bin/env bash
set -euo pipefail

if grep -R --line-number -E 'image:\s*.+:latest' broken >/dev/null; then
  echo 'policy check detected mutable tag in broken scenario (expected)'
else
  echo 'failed to detect mutable tag usage'
  exit 1
fi

echo 'verify: ok'
