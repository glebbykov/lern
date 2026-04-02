#!/usr/bin/env bash
set -euo pipefail

# Этот модуль не запускает контейнеры, только генерирует манифесты
rm -rf lab/generated/ 2>/dev/null || true

echo 'cleanup: done'
