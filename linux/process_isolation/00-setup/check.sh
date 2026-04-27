#!/usr/bin/env bash
# Проверяет, что хост готов к курсу. Выводит зелёные/красные галочки.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"

log "ядро и базовые возможности"

KVER=$(uname -r)
KMAJ=$(echo "$KVER" | cut -d. -f1)
KMIN=$(echo "$KVER" | cut -d. -f2)
note "kernel: $KVER"
if (( KMAJ > 5 )) || (( KMAJ == 5 && KMIN >= 10 )); then
  assert "kernel >= 5.10"          true
else
  assert "kernel >= 5.10"          false
fi

assert "cgroups v2 (unified hierarchy)" \
  bash -c 'mount | grep -q "cgroup2 on /sys/fs/cgroup"'

assert "user namespaces разрешены" \
  bash -c '[[ $(sysctl -n kernel.unprivileged_userns_clone 2>/dev/null || echo 1) == 1 ]]'

assert "/proc/self/ns/* существует (namespaces поддерживаются)" \
  test -e /proc/self/ns/uts

assert "AppArmor загружен в ядре" \
  bash -c '[[ -d /sys/kernel/security/apparmor ]]'

log "утилиты"
require_tools=(
  unshare nsenter ip setcap getcap capsh apparmor_parser systemd-nspawn
  debootstrap stress-ng busybox curl tar python3 strace
)
for t in "${require_tools[@]}"; do
  assert "найден: $t" command -v "$t"
done

log "опционально (не влияет на summary)"
info "fio для blkio-тестов"   command -v fio
info "Docker (для сравнения)" command -v docker

summary
