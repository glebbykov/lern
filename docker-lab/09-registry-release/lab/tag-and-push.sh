#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_LAB_DIR="$(cd "$MODULE_DIR/.." && pwd)"
SOURCE_CONTEXT="$DOCKER_LAB_DIR/02-images-dockerfile/lab"

: "${REGISTRY:?set REGISTRY}"
: "${REPO:?set REPO}"
: "${IMAGE:?set IMAGE}"
: "${VERSION:?set VERSION}"

full="${REGISTRY}/${REPO}/${IMAGE}"

docker build -t "${full}:${VERSION}" "$SOURCE_CONTEXT"
docker tag "${full}:${VERSION}" "${full}:stable"

docker push "${full}:${VERSION}"
docker push "${full}:stable"

echo "pushed: ${full}:${VERSION}"
