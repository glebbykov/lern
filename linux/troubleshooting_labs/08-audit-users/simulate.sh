#!/usr/bin/env bash
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Скрипт требует прав root!"
  exit 1
fi

echo "Имитируем неудачные попытки входа по SSH (брутфорс)..."
# В реальности мы бы долбились по ssh, но проще записать в auth.log/btmp
# Генерируем 3 failed login события для юзера 'hacker' через sshd
for i in {1..3}; do
  ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no hacker@127.0.0.1 "echo fail" >/dev/null 2>&1 || true
done

echo "Настраиваем auditd на слежение за файлом /tmp/top_secret.txt..."
touch /tmp/top_secret.txt
# Устанавливаем правило (w - watch, p wa - write/append, k - key)
auditctl -w /tmp/top_secret.txt -p wa -k secret_watch 2>/dev/null || echo "(Возможно, auditd не запущен, проверьте systemctl start auditd)"

echo "Имитируем изменение файла 'злоумышленником'..."
su - nobody -s /bin/bash -c 'echo "I changed this" > /tmp/top_secret.txt' 2>/dev/null || echo "I changed this" > /tmp/top_secret.txt

echo "Готово! Используй lastb и ausearch -k secret_watch для расследования!"
