# 11. Production patterns: blue/green, rollback, pre-deploy checks

## Зачем это важно

Деплой с даунтаймом неприемлем. Blue/green — один из простейших паттернов zero-downtime deployment: новая версия поднимается рядом со старой, трафик переключается мгновенно, откат — одна команда.

```text
             ┌──────────────┐
[curl :8087] │  nginx proxy │
             └──────┬───────┘
                    │ proxy_pass
           ┌────────┴────────┐
       blue │                │ green
  [app-blue:5678]      [app-green:5678]
   "blue" response      "green" response
```

---

## Часть 1 — Запуск стенда

```bash
docker compose -f lab/compose.yaml up -d

# Активная версия сейчас — blue
curl http://localhost:8087
# blue
```

### Что внутри

```bash
# Все сервисы запущены
docker compose -f lab/compose.yaml ps

# Proxy конфиг — куда идёт трафик?
docker exec $(docker compose -f lab/compose.yaml ps -q proxy) \
  cat /etc/nginx/conf.d/default.conf
# proxy_pass http://app-blue:5678;

# Оба бэкенда доступны, хотя трафик идёт только на blue
docker compose -f lab/compose.yaml exec proxy \
  sh -c "wget -qO- http://app-blue:5678 && wget -qO- http://app-green:5678"
# blue
# green
```

---

## Часть 2 — Переключение трафика

```bash
# Переключить на green
./lab/scripts/switch-to-green.sh
# nginx config test passed
# traffic switched to green

curl http://localhost:8087
# green

# Переключить обратно на blue
./lab/scripts/switch-to-blue.sh
# traffic switched to blue

curl http://localhost:8087
# blue
```

### Как работает переключение

```bash
# Посмотреть скрипт
cat lab/scripts/switch-to-green.sh
# 1. cp green.conf → default.conf   (меняем конфиг)
# 2. nginx -t                        (валидируем)
# 3. nginx -s reload                 (graceful reload без даунтайма)
```

---

## Часть 3 — Важность pre-deploy validation

```bash
# Никогда не делайте reload без nginx -t
# Симуляция: поломанный конфиг → что случится без -t?

docker compose -f lab/compose.yaml exec proxy \
  sh -c "nginx -t -c /etc/nginx/conf.d/default.conf 2>&1 || echo 'config invalid!'"

# Broken пример: прокси указывает на несуществующий сервис
docker compose -f lab/compose.yaml exec proxy \
  sh -c "echo 'server { listen 80; location / { proxy_pass http://app-purple:5678; } }' \
    > /tmp/bad.conf && nginx -t -c /tmp/bad.conf 2>&1 || echo 'detected: bad config'"
# nginx: [emerg] host not found in upstream "app-purple"
# detected: bad config
```

---

## Часть 4 — Smoke test перед переключением

В реальном деплое нужно проверить green перед переключением трафика:

```bash
# Проверить что green отвечает (до переключения трафика)
docker compose -f lab/compose.yaml exec proxy \
  sh -c "wget -qO- http://app-green:5678 | grep -q green && echo 'green: healthy'"
# green: healthy

# Только если healthy — переключаем
./lab/scripts/switch-to-green.sh
```

### Полный скрипт деплоя с проверками

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1. Smoke test green
echo "smoke test green..."
docker compose -f "$LAB_DIR/compose.yaml" exec -T proxy \
  sh -c "wget -qO- http://app-green:5678" | grep -q green
echo "green: ok"

# 2. Validate nginx config
cp "$LAB_DIR/proxy/green.conf" "$LAB_DIR/proxy/default.conf"
docker compose -f "$LAB_DIR/compose.yaml" exec -T proxy nginx -t

# 3. Graceful reload
docker compose -f "$LAB_DIR/compose.yaml" exec -T proxy nginx -s reload
echo "switched to green"

# 4. Verify after switch
sleep 1
curl -fsS http://localhost:8087 | grep -q green
echo "verified: green is live"
```

---

## Часть 5 — Broken: прокси на несуществующий сервис

```bash
# Запустить с битым конфигом
docker compose -f lab/compose.yaml exec proxy \
  sh -c "cp /dev/stdin /etc/nginx/conf.d/default.conf" \
  < broken/default.conf

# nginx перезагрузится, но не сможет проксировать
docker compose -f lab/compose.yaml exec proxy nginx -s reload 2>&1 || true

# Запросы теперь падают
curl http://localhost:8087 || echo "502 Bad Gateway — upstream не найден"

# Откат — вернуть blue конфиг
./lab/scripts/switch-to-blue.sh
curl http://localhost:8087
# blue  ← восстановлено
```

---

## Часть 6 — Эквиваленты в Kubernetes

| Compose (local) | Kubernetes |
|---|---|
| `app-blue`, `app-green` сервисы | `Deployment` с разными label-ами |
| nginx `proxy_pass` переключение | `Service` selector change или Ingress |
| `nginx -s reload` | `kubectl rollout restart` |
| `switch-to-green.sh` | `kubectl set image` или Argo Rollouts |
| `docker compose ps` | `kubectl get pods` |
| health через wget | `livenessProbe` / `readinessProbe` |

---

## Типовые ошибки

| Ошибка | Последствие | Исправление |
|---|---|---|
| `nginx -s reload` без `nginx -t` | Reload с невалидным конфигом → 502 | Всегда валидировать перед reload |
| Нет smoke test перед переключением | Переключили на нерабочую версию | Проверить health нового backend до switch |
| Нет rollback-плана | Невозможно быстро откатиться | `switch-to-blue.sh` всегда наготове |
| Blue и green пишут в один volume | Конфликт данных при переключении | Раздельное хранилище или миграции |

---

## Вопросы для самопроверки

1. Почему `nginx -s reload` не приводит к даунтайму?
2. Что произойдёт если `proxy_pass` указывает на несуществующий upstream?
3. Какой минимальный smoke test нужен перед переключением трафика?
4. Как замапить этот blue/green паттерн в Kubernetes primitives?
5. В чём ограничение blue/green на одном Docker-хосте?
6. Как добавить pre-deploy миграцию БД в этот flow?

---

## Cleanup

```bash
./cleanup.sh
```
