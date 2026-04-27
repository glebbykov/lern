#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/../scripts/lib.sh"

log "Тестируем Rootless (User Namespaces)"

if ! id labuser >/dev/null 2>&1; then
  useradd -m labuser
fi

OUT=$(su - labuser -c "unshare -U -r id -u")
assert "Внутри user-ns UID=0 (root)" test "$OUT" = "0"

su - labuser -c "unshare -U -m -r bash -c 'mount -t tmpfs none /mnt; touch /mnt/testfile; ls -n /mnt/testfile'" > /tmp/rootless-out.txt
assert "Файл успешно создан 'root-ом' внутри" grep -q ' 0 ' /tmp/rootless-out.txt

rm -f /tmp/rootless-out.txt
summary
