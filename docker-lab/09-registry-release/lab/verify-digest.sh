#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_REF:?set IMAGE_REF like ghcr.io/org/repo/image:1.0.0}"

docker buildx imagetools inspect "$IMAGE_REF"
