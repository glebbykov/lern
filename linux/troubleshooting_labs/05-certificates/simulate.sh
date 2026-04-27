#!/usr/bin/env bash
echo "Генерируем перепутанные сертификаты в /tmp/certs/..."
mkdir -p /tmp/certs
cd /tmp/certs

# Генерируем "просроченный" (на самом деле истекающий прямо сейчас) сертификат certA и его ключ key2
openssl req -new -newkey rsa:2048 -nodes -keyout key2.key -subj "/CN=expired.local" -out req.csr 2>/dev/null
openssl x509 -req -days 0 -in req.csr -signkey key2.key -out certA.crt 2>/dev/null
rm -f req.csr

# Генерируем нормальный сертификат certB и его ключ key1
openssl req -x509 -newkey rsa:2048 -keyout key1.key -out certB.crt -days 365 -nodes -subj "/CN=valid.local" 2>/dev/null

echo "Готово! В /tmp/certs/ лежат certA.crt, certB.crt, key1.key, key2.key."
echo "Найди, какой сертификат действителен и какой ключ к нему подходит!"
