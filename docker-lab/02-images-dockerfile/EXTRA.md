# 02 — Дополнительные материалы

## Node.js Dockerfile (lab/node-app/)

Multi-stage Dockerfile для Express.js приложения:

```bash
# Собрать Node.js образ
docker build -t dockerlab/node-app:dev ./lab/node-app

# Запустить
docker run --rm -p 3000:3000 dockerlab/node-app:dev
curl http://localhost:3000/healthz
```

### Ключевые паттерны Node.js

| Паттерн | Зачем |
|---|---|
| `npm ci` вместо `npm install` | Воспроизводимые зависимости (strict lockfile) |
| `COPY package*.json` до `COPY . .` | Кеш npm install при изменении кода |
| `USER node` | Встроенный non-root user в node-образах |
| `--omit=dev` | Не тащить devDependencies в production |
| `.dockerignore` с `node_modules` | Не копировать локальные модули в контекст |

---

## BuildKit Secrets (lab/buildkit-secrets/)

`RUN --mount=type=secret` — безопасная передача секретов на этапе сборки.
Секрет доступен **только** во время выполнения RUN, не сохраняется в слоях.

```bash
# Создать секрет
echo "my-api-key-12345" > /tmp/api_key.txt

# Собрать с секретом
docker build \
  --secret id=api_key,src=/tmp/api_key.txt \
  -t dockerlab/secret-demo:dev \
  ./lab/buildkit-secrets

# Проверить: секрет НЕ виден в history
docker history dockerlab/secret-demo:dev --no-trunc
# → строка с --mount=type=secret, но содержимое секрета отсутствует

# Сравнить с ARG-подходом (модуль broken/Dockerfile.bad):
# docker history dockerlab/simple-web:bad --no-trunc | grep SECRET
# → ARG виден!
```

---

## Broken: Layer Leak (broken/Dockerfile.layer-leak)

`COPY . .` без `.dockerignore` копирует `.env` с секретами в образ:

```bash
docker build -t test-leak -f broken/Dockerfile.layer-leak ./broken/layer-leak-ctx
docker run --rm test-leak cat /app/.env
# DATABASE_PASSWORD=super_secret  ← УТЕЧКА!
docker rmi test-leak
```
