#!/usr/bin/env bash
# Ставит все пакеты, которые потребуются курсу.
# Только Ubuntu/Debian. На других дистрибутивах — поставь руками.
set -euo pipefail
. "$(dirname "$0")/../scripts/lib.sh"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Требуется apt (Ubuntu/Debian). Поставь пакеты вручную, см. README." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log "apt-get update"
apt-get update -y

log "установка пакетов"
apt-get install -y \
  coreutils util-linux iproute2 \
  busybox-static procps \
  python3 python3-pip \
  libcap2-bin \
  apparmor apparmor-utils \
  systemd-container \
  bridge-utils \
  debootstrap \
  curl tar \
  stress-ng fio \
  strace ltrace \
  iputils-ping \
  ca-certificates

log "готово. Перепроверь:  sudo ./check.sh"
