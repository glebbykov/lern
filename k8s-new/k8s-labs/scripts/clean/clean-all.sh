#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Clean modules (lab namespace)
for module in "$ROOT_DIR"/modules/*; do
  [[ -d "$module" ]] || continue
  kubectl -n lab delete -f "$module/manifests" --ignore-not-found=true || true
  kubectl -n lab delete -f "$module/broken" --ignore-not-found=true || true
  kubectl -n lab delete -f "$module/solutions" --ignore-not-found=true || true
done

# Clean projects (lab + platform namespaces)
for project in "$ROOT_DIR"/projects/*; do
  [[ -d "$project" ]] || continue
  for ns in lab platform; do
    if [[ -d "$project/manifests" ]]; then
      kubectl -n "$ns" delete -f "$project/manifests" --ignore-not-found=true || true
    fi
    if [[ -d "$project/broken" ]]; then
      kubectl -n "$ns" delete -f "$project/broken" --ignore-not-found=true || true
    fi
    if [[ -d "$project/solutions" ]]; then
      kubectl -n "$ns" delete -f "$project/solutions" --ignore-not-found=true || true
    fi
  done
done

echo "cleanup finished (lab + platform namespaces)"
