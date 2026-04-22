#!/usr/bin/env bash
# Этап 4 — активные попытки взлома захардененного контейнера stage3.
# Для каждой атаки печатаем либо "✓ blocked (...)", либо
# "✗ FAIL (защита не работает)". В конце — сумма.
#
# Замечание про выбор проверок: современный Docker даёт контейнеру
#   net.ipv4.ip_unprivileged_port_start=0  и  net.ipv4.ping_group_range=0 0
# поэтому bind на 80 и классический ping уже не требуют capabilities
# и НЕ годятся как индикатор работы cap_drop. Используем проверки,
# которые точно зависят от конкретных капов.
set -uo pipefail
cd "$(dirname "$0")"

CONTAINER=hardening-stage3
PASS=0
FAIL=0

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "Контейнер ${CONTAINER} не запущен. Сначала прогоните stage3."
  exit 1
fi

check_block() {
  local desc="$1"; shift
  local output
  if output=$("$@" 2>&1); then
    echo "✗ FAIL: ${desc} — команда прошла, защита НЕ сработала"
    echo "   output: $output"
    FAIL=$((FAIL+1))
  else
    echo "✓ blocked: ${desc}"
    echo "   reason: $(echo "$output" | head -n1)"
    PASS=$((PASS+1))
  fi
}

echo "=== stage4: попытки взлома ==="

# --- read_only rootfs --------------------------------------------------------
check_block "touch /pwned.txt (read_only rootfs)" \
  docker exec "${CONTAINER}" sh -c 'touch /pwned.txt'

check_block "echo > /app/pwned (read_only rootfs)" \
  docker exec "${CONTAINER}" sh -c 'echo x > /app/pwned'

echo -n "   проверка /tmp (должна пройти): "
docker exec "${CONTAINER}" sh -c 'touch /tmp/ok && echo ok' || echo "не прошла — это странно"

# --- capabilities ------------------------------------------------------------
# CAP_CHOWN
check_block "chown root:root /tmp/ok (нет CAP_CHOWN)" \
  docker exec "${CONTAINER}" sh -c 'chown root:root /tmp/ok'

# CAP_NET_RAW — нужен для SOCK_RAW, НО не для SOCK_DGRAM ICMP
check_block "SOCK_RAW (нет CAP_NET_RAW)" \
  docker exec "${CONTAINER}" python -c \
    'import socket; socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_ICMP)'

# CAP_MKNOD — создание блочного устройства
check_block "mknod /tmp/disk b 8 0 (нет CAP_MKNOD)" \
  docker exec "${CONTAINER}" sh -c 'mknod /tmp/disk b 8 0'

# CAP_SYS_ADMIN — mount
check_block "mount -t tmpfs none /mnt (нет CAP_SYS_ADMIN)" \
  docker exec "${CONTAINER}" sh -c 'mount -t tmpfs none /mnt'

# CAP_SYS_TIME — установка системного времени.
# Намеренно не используем busybox `date -s`: у него exit code 0
# даже когда ядро отказало ("Operation not permitted"). Используем
# честный syscall через python — он бросит PermissionError.
check_block "clock_settime (нет CAP_SYS_TIME)" \
  docker exec "${CONTAINER}" python -c \
    'import time; time.clock_settime(time.CLOCK_REALTIME, 0.0)'

# CAP_SYSLOG / CAP_SYS_ADMIN — dmesg (в alpine нет — имитируем через /dev/kmsg)
check_block "read /dev/kmsg (нет CAP_SYSLOG)" \
  docker exec "${CONTAINER}" sh -c 'head -c 1 /dev/kmsg'

# --- no-new-privileges -------------------------------------------------------
# Классический тест: setuid-бинарь должен не поднять привилегии.
# В alpine-python образе есть /bin/busybox, у которого НЕТ suid-бита.
# Установим suid на /bin/ls (должно быть нельзя — read_only + нет CAP_FSETID).
check_block "chmod u+s /bin/ls (read_only + нет CAP_FSETID)" \
  docker exec "${CONTAINER}" sh -c 'chmod u+s /bin/ls'

echo
echo "=== итог: ${PASS} blocked / ${FAIL} passed ==="
if [[ $FAIL -ne 0 ]]; then
  echo "Хотя бы одна защита не сработала — посмотрите вывод выше."
  exit 1
fi
echo "Все атакующие действия заблокированы — hardening работает."
