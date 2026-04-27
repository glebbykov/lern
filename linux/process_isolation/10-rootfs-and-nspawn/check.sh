#!/usr/bin/env bash
# Автотест 10: rootfs скачан и запускается через nspawn.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require curl tar systemd-nspawn

ALPINE_DIR=/lab/10/alpine
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.1-x86_64.tar.gz"

if ! [[ -f "$ALPINE_DIR/etc/os-release" ]]; then
  log "alpine rootfs ещё не скачан — качаем"
  rm -rf /lab/10
  mkdir -p "$ALPINE_DIR"
  curl -fsSL "$ALPINE_URL" | tar -xz -C "$ALPINE_DIR"
fi

assert "alpine rootfs существует и содержит /bin/sh" \
  test -x "$ALPINE_DIR/bin/sh"

assert "/etc/os-release говорит Alpine" \
  bash -c 'grep -q "Alpine" '"$ALPINE_DIR"'/etc/os-release'

# nspawn запускает контейнер, проверяем что внутри — alpine, PID 1 — наш.
OS=$(systemd-nspawn -q -D "$ALPINE_DIR" --pipe -- /bin/sh -c 'cat /etc/os-release | grep ^ID=')
note "ID внутри nspawn: $OS"
assert "внутри nspawn ID=alpine" \
  bash -c '[[ "'"$OS"'" == *"alpine"* ]]'

# Bash/ash оптимизируют exec для последней команды в `-c` даже если перед
# ней был `true;`. Чтобы sh ОСТАЛСЯ как PID 1 — заворачиваем cat в command
# substitution (тогда cat запускается как форк, sh не exec-ает).
PID1_NAME=$(systemd-nspawn -q -D "$ALPINE_DIR" --pipe -- /bin/sh -c 'p=$(cat /proc/1/comm); echo "$p"')
note "PID 1 внутри: $PID1_NAME"
assert "PID 1 внутри nspawn = sh (PID-ns изолирован)" \
  bash -c '[[ "'"$PID1_NAME"'" == "sh" ]]'

# проверим, что hostname внутри nspawn другой
HOST_HN=$(hostname)
NS_HN=$(systemd-nspawn -q -D "$ALPINE_DIR" --pipe -- /bin/sh -c 'hostname' | tr -d '\r\n ')
note "hostname в nspawn: '$NS_HN' (на хосте: '$HOST_HN')"
assert "hostname в nspawn отличается от хостового (UTS-ns)" \
  bash -c '[[ "'"$NS_HN"'" != "'"$HOST_HN"'" ]]'

summary
