#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/../scripts/lib.sh"

log "Тестируем OCI runc"

assert "Утилита runc установлена" command -v runc

BUNDLE="/tmp/runc-bundle"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/rootfs/bin"
cp /bin/busybox "$BUNDLE/rootfs/bin/"
chroot "$BUNDLE/rootfs" /bin/busybox --install -s /bin || true

cd "$BUNDLE"
runc spec

python3 -c "
import json
with open('config.json') as f: d = json.load(f)
d['process']['args'] = ['/bin/sh', '-c', 'echo OCI-RUNC-SUCCESS > /out.txt']
d['process']['terminal'] = False
d['root']['readonly'] = False
with open('config.json', 'w') as f: json.dump(d, f)
"

runc run test-runc-ctr > /dev/null 2>&1 || true

assert "Контейнер успешно отработал через runc" \
  grep -q 'OCI-RUNC-SUCCESS' "$BUNDLE/rootfs/out.txt"

rm -rf "$BUNDLE"
summary
