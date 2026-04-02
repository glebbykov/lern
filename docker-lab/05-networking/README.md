# 05. Networking: bridge, DNS, порты, изоляция

## Зачем это важно

По умолчанию контейнеры запускаются в изолированной сети. Чтобы они общались между собой или были доступны снаружи, Docker строит виртуальные сети поверх хостового сетевого стека. Понимание этого — основа для любой микросервисной архитектуры.

## Как это устроено

```text
Хост
│
├── eth0 (внешний интерфейс, например 192.168.1.10)
│
└── docker0 (bridge по умолчанию)
     ├── veth-abc ──► container: edge   172.17.0.2
     ├── veth-def ──► container: api    172.17.0.3
     └── veth-ghi ──► container: db     172.17.0.4

Custom bridge (my_net):
     ├── veth-xxx ──► container: edge   172.20.0.2
     └── veth-yyy ──► container: api    172.20.0.3
         └── DNS: "api" → 172.20.0.3   ← встроенный резолвер Docker
```

**Custom bridge vs default bridge:**

| Свойство | default bridge | custom bridge |
|---|---|---|
| DNS по имени контейнера | Нет | Да |
| Изоляция от других контейнеров | Нет | Да |
| Создаётся в compose автоматически | — | Да |
| Рекомендуется для продакшн | Нет | Да |

---

## Стенд

Текущая топология (`lab/compose.yaml`):

```text
[хост :8082] ──publish──► [edge: nginx]
                                │  frontend сеть
                           [api: http-echo]
                                │  backend сеть
                            [db: redis]

[toolbox: alpine] ── frontend + backend (для диагностики)
```

- `edge` — единственный сервис с публичным портом
- `api` — внутренний, виден только в своих сетях
- `db` — только в backend, edge до него не дотянется
- `toolbox` — в обеих сетях, используется для `nslookup`/`wget`/`nc`

---

## Часть 1 — Запуск и базовая проверка доступности

```bash
docker compose -f lab/compose.yaml up -d
```

### Доступ снаружи (publish)

```bash
# edge опубликован на хосте — должен ответить
curl http://localhost:8082
# ответ: "api ok"
```

### DNS внутри контейнера

Docker DNS резолвит имя сервиса в IP прямо внутри сети. Это работает только в custom bridge.

```bash
# nslookup по имени сервиса из toolbox
docker compose -f lab/compose.yaml exec toolbox nslookup api
docker compose -f lab/compose.yaml exec toolbox nslookup db
docker compose -f lab/compose.yaml exec toolbox nslookup edge
```

Обрати внимание: все три имени резолвятся, хотя `edge` и `db` в разных сетях — потому что `toolbox` подключён к обеим.

### Inspect сетей

```bash
# Какие сети созданы?
docker network ls

# Кто в frontend сети?
docker network inspect 05-networking_frontend

# Посмотреть IP каждого контейнера
docker compose -f lab/compose.yaml ps
docker inspect $(docker compose -f lab/compose.yaml ps -q api) \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}'
```

---

## Часть 2 — Изоляция: кто кого видит

Главный вопрос: если `edge` не в backend сети — может ли он достучаться до `db`?

```bash
# edge пробует достучаться до db по имени
docker compose -f lab/compose.yaml exec edge \
  sh -c "nslookup db || echo 'DNS fail'"

# edge пробует достучаться до db напрямую по порту
docker compose -f lab/compose.yaml exec edge \
  sh -c "nc -zw2 db 6379 && echo 'open' || echo 'closed'"
```

Обе команды должны завершиться ошибкой — `edge` не знает о `db`, потому что они в разных сетях.

```bash
# toolbox в обеих сетях — он видит db
docker compose -f lab/compose.yaml exec toolbox \
  sh -c "nc -zw2 db 6379 && echo 'open' || echo 'closed'"
# ответ: open
```

**Вывод:** сеть в Docker — граница изоляции. Сервисы видят только тех, кто в одной с ними сети.

---

## Часть 3 — Broken: контейнер не в той сети

Посмотри на `broken/compose.yaml` — `api` убран из backend сети. Он не может резолвить `db`.

```bash
docker compose -f broken/compose.yaml up -d

# toolbox пробует достучаться до api — ok, они оба в frontend
docker compose -f broken/compose.yaml exec toolbox \
  sh -c "nc -zw2 api 5678 && echo 'open' || echo 'closed'"

# api пробует достучаться до db — fail, api не в backend сети
docker compose -f broken/compose.yaml exec api \
  sh -c "nslookup db || echo 'DNS fail: api cannot see db'"

docker compose -f broken/compose.yaml down
```

---

## Часть 4 — Network aliases: один сервис, несколько имён

Alias позволяет обращаться к контейнеру по нескольким именам в рамках одной сети. Полезно для сине-зелёного деплоя, миграций, совместимости.

```bash
docker compose -f lab/02-aliases/compose.yaml up -d

# v2 отвечает на имя "api" — через alias
docker compose -f lab/02-aliases/compose.yaml exec toolbox \
  sh -c "wget -qO- http://api:5678"
# ответ: "v2 response"

# v2 также отвечает на собственное имя "api-v2"
docker compose -f lab/02-aliases/compose.yaml exec toolbox \
  sh -c "wget -qO- http://api-v2:5678"

# v1 отвечает только на своё имя, алиас уже занят v2
docker compose -f lab/02-aliases/compose.yaml exec toolbox \
  sh -c "wget -qO- http://api-v1:5678"

docker compose -f lab/02-aliases/compose.yaml down
```

---

## Часть 5 — Internal network: полная изоляция от интернета

`internal: true` запрещает любой трафик между сетью и внешним миром. Контейнеры в такой сети не имеют маршрута наружу.

```bash
docker compose -f lab/03-internal-net/compose.yaml up -d

# backend-only контейнер НЕ может выйти в интернет
docker compose -f lab/03-internal-net/compose.yaml exec backend \
  sh -c "wget -T3 -qO- http://example.com || echo 'no internet — expected'"

# но backend видит db внутри той же internal сети
docker compose -f lab/03-internal-net/compose.yaml exec backend \
  sh -c "nc -zw2 db 6379 && echo 'db reachable' || echo 'db unreachable'"

# frontend видит internet (не internal сеть)
docker compose -f lab/03-internal-net/compose.yaml exec frontend \
  sh -c "wget -T3 -qO- http://example.com | head -3 || echo 'no internet'"

docker compose -f lab/03-internal-net/compose.yaml down
```

**Когда использовать:** БД, очереди, внутренние API — всё что не должно выходить в интернет самостоятельно.

---

## Часть 6 — EXPOSE vs publish (-p)

```bash
# EXPOSE — метаданные образа, НЕ открывает порт на хосте
docker inspect nginx:1.27-alpine --format '{{json .Config.ExposedPorts}}'
# {"80/tcp":{}}  ← задекларировано, но не опубликовано

# Запустим контейнер без -p
docker run -d --name test-expose nginx:1.27-alpine
curl http://localhost:80    # connection refused — порт не опубликован

# Запустим с публикацией
docker run -d --name test-publish -p 8099:80 nginx:1.27-alpine
curl http://localhost:8099  # 200 OK

# Очистка
docker rm -f test-expose test-publish
```

**Разница:**
- `EXPOSE 80` — документация для `docker inspect` и межсервисного общения
- `-p 8080:80` / `ports:` в compose — реальная публикация на хост

---

## Часть 7 — Диагностика сети

```bash
# Все сети проекта
docker network ls --filter label=com.docker.compose.project=05-networking

# Детали сети: подсеть, gateway, контейнеры
docker network inspect 05-networking_backend

# IP конкретного контейнера
docker inspect <container_id> \
  --format '{{range .NetworkSettings.Networks}}{{.NetworkID}}: {{.IPAddress}}{{println}}{{end}}'

# Маршрутная таблица внутри контейнера
docker compose -f lab/compose.yaml exec toolbox ip route

# Открытые соединения
docker compose -f lab/compose.yaml exec toolbox ss -tulnp

# Трассировка маршрута до api
docker compose -f lab/compose.yaml exec toolbox traceroute api
```

---

## Сравнение режимов сети

| Режим | Изоляция | DNS | Use case |
|---|---|---|---|
| `bridge` (custom) | Высокая | Да, по имени сервиса | Все compose-проекты |
| `bridge` (default) | Низкая | Нет | Устаревший, не использовать |
| `host` | Нет — шарит сеть хоста | — | Высокая производительность, мониторинг |
| `none` | Полная | Нет | Security sandbox |
| `internal: true` | От внешней сети | Да | БД, внутренние сервисы |

---

## Типовые ошибки

| Ошибка | Причина | Диагностика |
|---|---|---|
| Сервис не резолвится по имени | Контейнеры в разных сетях | `docker network inspect` |
| Порт открыт, но недоступен с хоста | `EXPOSE` вместо `ports:` | `docker ps` — нет `0.0.0.0:PORT` |
| Порт слушает, но connect refused | Сервис внутри слушает `127.0.0.1`, не `0.0.0.0` | `ss -tulnp` внутри контейнера |
| Два compose-проекта не видят друг друга | Разные сети по умолчанию | Явно указать общую сеть как `external: true` |
| `network_mode: host` на Mac/Windows | host-режим работает только на Linux | Использовать publish ports |

---

## Вопросы для самопроверки

1. В чём принципиальная разница между `EXPOSE` и `ports:` в compose?
2. Почему `db` не должен иметь опубликованного порта в продакшн?
3. Как сделать, чтобы два разных compose-проекта видели друг друга?
4. Что произойдёт, если запустить два compose-проекта с одинаковым именем сети?
5. Почему `network_mode: host` не работает на Docker Desktop (Mac/Windows)?
6. Что такое network alias и когда он нужен?
7. Чем опасна `internal: false` сеть для БД?

---

## Cleanup

```bash
./cleanup.sh
```
