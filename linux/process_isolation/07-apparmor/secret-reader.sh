#!/usr/bin/env bash
# Тестовый скрипт: пытается читать /etc/passwd и писать в /var/log
# и в /tmp. Под AppArmor-профилем должны пройти только разрешённые операции.
set -uo pipefail

echo "uid: $(id -u)"

if cat /etc/passwd >/dev/null 2>&1; then
  echo "READ_PASSWD: OK"
else
  echo "READ_PASSWD: DENIED"
fi

if echo test > /var/log/aa-test.log 2>/dev/null; then
  echo "WRITE_VARLOG: OK"
  rm -f /var/log/aa-test.log
else
  echo "WRITE_VARLOG: DENIED"
fi

if echo test > /tmp/aa-test.log 2>/dev/null; then
  echo "WRITE_TMP: OK"
  rm -f /tmp/aa-test.log
else
  echo "WRITE_TMP: DENIED"
fi
