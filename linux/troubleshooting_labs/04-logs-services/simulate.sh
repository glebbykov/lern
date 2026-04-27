#!/usr/bin/env bash
echo "Создаем сломанный systemd сервис..."

cat << 'SVC' > /etc/systemd/system/broken-app.service
[Unit]
Description=My Broken App

[Service]
Type=simple
ExecStart=/bin/bash -c "cat /tmp/magic_config.ini || exit 1; echo 'APP STARTED SUCCESSFULLY'; sleep 1000"
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
SVC

rm -f /tmp/magic_config.ini
systemctl daemon-reload
systemctl restart broken-app || true

echo "Сервис 'broken-app' запущен, но он постоянно падает. Используй systemctl status broken-app и journalctl -u broken-app чтобы понять почему!"
