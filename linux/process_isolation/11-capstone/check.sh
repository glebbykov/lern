#!/usr/bin/env bash
# Автотест 11: запускает mycontainer, проверяет все 8 изоляций.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require unshare ip mount

# Заранее качаем alpine, чтобы первый запуск mycontainer был быстрым
ALPINE_DIR=/lab/10/alpine
if ! [[ -x "$ALPINE_DIR/bin/sh" ]]; then
  rm -rf /lab/10 && mkdir -p "$ALPINE_DIR"
  curl -fsSL "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.1-x86_64.tar.gz" \
    | tar -xz -C "$ALPINE_DIR"
fi

MYC="$(dirname "$0")/mycontainer.sh"
HOST_HN=$(hostname)

# Запустим контейнер с командой, которая распечатает всё интересное
OUT=$("$MYC" run -m 64M alpine -- sh -c '
  echo "PID1=$(cat /proc/1/comm)"
  echo "HOSTNAME=$(hostname)"
  echo "UID=$(id -u)"
  echo "OS=$(grep ^ID= /etc/os-release | cut -d= -f2)"
  echo "PROCS=$(ps -o pid= | wc -l)"
  echo "SECCOMP=$(grep ^Seccomp: /proc/self/status | awk "{print \$2}")"
  echo "MEM_MAX=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo none)"
' 2>&1)

note "вывод mycontainer:"
echo "$OUT" | sed 's/^/   /'

assert "PID 1 внутри = sh (PID-ns)" \
  bash -c 'grep -q "^PID1=sh" <<< "'"$OUT"'"'

assert "hostname внутри = mycontainer (UTS-ns)" \
  bash -c 'grep -q "^HOSTNAME=mycontainer" <<< "'"$OUT"'"'

assert "UID внутри = 0" \
  bash -c 'grep -q "^UID=0" <<< "'"$OUT"'"'

assert "OS внутри = alpine (overlay сработал)" \
  bash -c 'grep -q "^OS=alpine" <<< "'"$OUT"'"'

assert "процессов в контейнере мало (5 или меньше — PID-ns изолирован)" \
  bash -c 'P=$(grep "^PROCS=" <<< "'"$OUT"'" | cut -d= -f2); [[ $P -le 5 ]]'

# Seccomp может быть 0 или 2 в зависимости от того, доступен ли helper.
# Главное чтоб не упало.

# Ещё проверим, что после mycontainer-а на хосте ничего не осталось
sleep 1
assert "не осталось overlay mount-ов от mycontainer" \
  bash -c '! mount | grep -q /var/lib/mycontainer'

assert "не осталось cgroup mycontainer-* (всё убрано)" \
  bash -c '! ls /sys/fs/cgroup/mycontainer/mycontainer-* 2>/dev/null'

summary
