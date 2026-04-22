#!/usr/bin/env bash
# Собирает и запускает anti-pattern контейнер, затем показывает
# всё, что в нём не так: root-пользователя, ENV-секрет, запись в /.
set -euo pipefail
cd "$(dirname "$0")"

cp ../common/app_env.py app.py
cp ../common/requirements.txt requirements.txt

echo "==> docker compose build (stage0)"
docker compose build

echo "==> docker compose up -d"
docker compose up -d

echo "==> ждём, пока /healthz ответит"
for _ in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8083/healthz >/dev/null 2>&1; then break; fi
  sleep 0.5
done
curl -fsS http://127.0.0.1:8083/healthz; echo

echo "==> кто я внутри контейнера?"
docker exec hardening-stage0 id

echo "==> секрет виден в ENV (плохо):"
docker exec hardening-stage0 env | grep -E '^SECRET=' || true

echo "==> секрет утёк в слои образа? (docker history):"
docker history --no-trunc hardening-stage0 | grep -i 'SECRET' || echo "не видно в CMD, но виден через env/inspect"

echo "==> запись в корень файловой системы контейнера (НЕ должно быть ошибки):"
docker exec hardening-stage0 sh -c 'touch /pwned.txt && ls -l /pwned.txt'

echo "==> capabilities у процесса (их целая пачка):"
docker exec hardening-stage0 sh -c 'grep CapEff /proc/1/status'

echo "==> /secret ответ:"
curl -fsS http://127.0.0.1:8083/secret; echo

echo
echo "Вывод: stage0 запущен от root, капов полно, секрет в ENV,"
echo "файловая система rw — всё, что быть не должно."
