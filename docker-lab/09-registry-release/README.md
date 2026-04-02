# 09. Registry и release flow

## Зачем это важно

`image:latest` — не версия. Два деплоя с тегом `latest` могут запустить абсолютно разные образы. Правильный release flow: каждый образ идентифицируется неизменяемым тегом и digest.

```text
Плохо:   image: myapp:latest   ← что именно запущено?
Хорошо:  image: myapp:1.3.2    ← конкретная версия
Лучше:   image: myapp@sha256:abc123...  ← digest, нельзя подменить
```

---

## Часть 1 — Локальный registry

Для практики используем локальный registry — не нужен аккаунт на Docker Hub.

```bash
# Поднять локальный registry
docker run -d --name registry -p 5000:5000 registry:2

# Проверить
curl http://localhost:5000/v2/
# {}  ← registry работает
```

---

## Часть 2 — Tag, push, pull

```bash
# Собрать образ (используем app из модуля 08)
docker build -t localhost:5000/myapp:1.0.0 ../08-build-advanced/lab

# Добавить alias-тег stable
docker tag localhost:5000/myapp:1.0.0 localhost:5000/myapp:stable

# Запушить оба тега
docker push localhost:5000/myapp:1.0.0
docker push localhost:5000/myapp:stable

# Список образов в registry
curl -s http://localhost:5000/v2/myapp/tags/list
# {"name":"myapp","tags":["1.0.0","stable"]}
```

---

## Часть 3 — Digest: неизменяемый идентификатор

Тег — мутабельный указатель (можно перезаписать). Digest — хеш содержимого (неизменяем).

```bash
# Получить digest образа
docker inspect localhost:5000/myapp:1.0.0 \
  --format '{{index .RepoDigests 0}}'
# localhost:5000/myapp@sha256:abc123...

# Или через buildx imagetools (после push)
docker buildx imagetools inspect localhost:5000/myapp:1.0.0

# Получить digest через registry API
curl -s \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://localhost:5000/v2/myapp/manifests/1.0.0 \
  -D - 2>&1 | grep -i docker-content-digest
# Docker-Content-Digest: sha256:abc123...
```

### Почему тег != идентификатор

```bash
# Собрать новый образ и запушить под тем же тегом
echo "FROM nginx:1.27-alpine" | docker build -t localhost:5000/myapp:stable -

docker push localhost:5000/myapp:stable
# ← stable теперь указывает на другой образ!

# 1.0.0 и stable — разные образы под одним именем
docker pull localhost:5000/myapp:1.0.0 && \
  docker inspect localhost:5000/myapp:1.0.0 --format '{{.Id}}'

docker pull localhost:5000/myapp:stable && \
  docker inspect localhost:5000/myapp:stable --format '{{.Id}}'
# Разные ID!
```

---

## Часть 4 — Immutable release: semver + digest

```bash
# Правильный релизный цикл:

# 1. Собрать с версионным тегом
docker build -t localhost:5000/myapp:1.1.0 ../08-build-advanced/lab

# 2. Запушить
docker push localhost:5000/myapp:1.1.0

# 3. Зафиксировать digest
DIGEST=$(docker inspect localhost:5000/myapp:1.1.0 \
  --format '{{index .RepoDigests 0}}')
echo "Released: $DIGEST"
# Released: localhost:5000/myapp@sha256:...

# 4. В production деплоить по digest, не по тегу
# image: localhost:5000/myapp@sha256:abc123...  ← нельзя случайно подменить
```

---

## Часть 5 — Policy check: запрет `:latest` в release-манифестах

```bash
# Broken пример: latest в production-манифесте
cat broken/release-manifest.yaml
# image: ghcr.io/example/simple-web:latest  ← нарушение политики

# Policy check — ловим latest
grep -rn 'image:.*:latest' broken/
# broken/release-manifest.yaml:3:  image: ghcr.io/example/simple-web:latest

# Более строгая проверка: любой mutable-тег (latest, stable, dev)
grep -rn --include='*.yaml' 'image:.*:\(latest\|stable\|dev\)$' broken/
```

### Policy check как bash-функция

```bash
check_no_latest() {
  local file="$1"
  if grep -qE 'image:\s*.+:(latest|stable|dev)$' "$file"; then
    echo "FAIL: mutable tag in $file"
    grep -nE 'image:\s*.+:(latest|stable|dev)$' "$file"
    return 1
  fi
  echo "OK: $file"
}

check_no_latest broken/release-manifest.yaml
# FAIL: mutable tag in broken/release-manifest.yaml

check_no_latest lab/release.env.example
# OK: lab/release.env.example
```

---

## Часть 6 — Очистка registry

```bash
# Список всех репозиториев в локальном registry
curl -s http://localhost:5000/v2/_catalog
# {"repositories":["myapp"]}

# Список тегов конкретного образа
curl -s http://localhost:5000/v2/myapp/tags/list

# Удалить образ из registry (через digest)
DIGEST=$(curl -s \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://localhost:5000/v2/myapp/manifests/stable \
  -D - 2>&1 | grep -i docker-content-digest | awk '{print $2}' | tr -d '\r')

curl -X DELETE "http://localhost:5000/v2/myapp/manifests/$DIGEST"
```

---

## Broken примеры

| Файл | Проблема |
|---|---|
| `broken/release-manifest.yaml` | `image: ...:latest` — mutable тег в production |

---

## Типовые ошибки

| Ошибка | Последствие | Исправление |
|---|---|---|
| `latest` в docker-compose production | Неизвестно что запущено, деплой недетерминирован | Semver тег или digest |
| Push от "грязной" локальной сборки | Разные артефакты на разных машинах | Собирать только в CI |
| Перезапись версионного тега | Нарушение immutability, невозможен rollback | Запретить re-push на уровне registry |
| Нет digest в release notes | Нельзя воспроизвести точно тот же образ | Документировать digest при каждом релизе |

---

## Вопросы для самопроверки

1. Почему `image:latest` — anti-pattern в production?
2. Что такое digest и чем он принципиально отличается от тега?
3. Два деплоя с `image:stable` — гарантированно ли они запустят одинаковый образ?
4. Где в CI/CD pipeline правильно делать policy check на mutable-теги?
5. Как откатиться на предыдущую версию если latest уже перезаписан?

---

## Cleanup

```bash
./cleanup.sh
```
