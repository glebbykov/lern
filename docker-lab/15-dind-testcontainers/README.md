# 15. Docker in Docker и Testcontainers

## Зачем это важно

CI/CD pipeline часто должен собирать Docker-образы внутри Docker-контейнера (Jenkins, GitLab Runner). Testcontainers позволяют запускать настоящие БД/очереди в интеграционных тестах вместо моков. Оба сценария требуют понимания того, как Docker работает внутри Docker.

```text
Подход             Как работает                      Когда используется
────────────────────────────────────────────────────────────────────────
Socket mount       Маунт /var/run/docker.sock        CI: Jenkins, GitLab Runner
DinD (privileged)  Docker daemon внутри контейнера   Изолированный CI, Kubernetes
Sysbox             Без привилегий, userspace         Security-first среда
Testcontainers     SDK для запуска контейнеров        Интеграционные тесты
```

---

## Prereq

- Docker Engine/Desktop запущен.
- Понимание volumes (модуль 04), networking (модуль 05), security (модуль 07).
- Go 1.24+ или Python 3.12+ (для Testcontainers).

---

## Часть 1 — Socket Mount: Docker снаружи, управление изнутри

Самый простой способ — примонтировать Docker-сокет хоста в контейнер. Контейнер не запускает свой Docker daemon, а управляет daemon хоста.

```text
┌──────────────────────────────────────┐
│           Хост (Docker daemon)       │
│  /var/run/docker.sock                │
│       ▲                              │
│       │ mount                        │
│  ┌────┴──────────────┐               │
│  │ CI-контейнер      │               │
│  │ docker build ...  ├──► создаёт    │
│  │ docker run ...    │   контейнеры  │
│  └───────────────────┘   на хосте    │
└──────────────────────────────────────┘
```

### Практика

```bash
# Запустить контейнер с docker CLI + маунт сокета
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  docker:27-cli \
  sh

# Внутри контейнера — мы управляем Docker ХОСТА
docker ps          # видим ВСЕ контейнеры хоста
docker images      # видим ВСЕ образы хоста
docker info        # Docker info хоста
exit
```

### Compose: CI-runner с socket mount

```bash
docker compose -f lab/socket-mount/compose.yaml up -d

# CI-контейнер может собирать образы
docker compose -f lab/socket-mount/compose.yaml exec ci-runner \
  docker build -t test-from-ci /workspace

# И запускать другие контейнеры (на ХОСТЕ!)
docker compose -f lab/socket-mount/compose.yaml exec ci-runner \
  docker run --rm alpine:3.20 echo "built from inside CI"

docker compose -f lab/socket-mount/compose.yaml down
```

### Риски socket mount

```bash
# ОПАСНО: CI-контейнер имеет полный контроль над Docker daemon хоста
# Он может:
docker compose -f lab/socket-mount/compose.yaml exec ci-runner \
  docker rm -f $(docker ps -q)    # убить ВСЕ контейнеры

# Он может читать secrets из других контейнеров:
# docker inspect <other-container> --format '{{range .Config.Env}}{{println .}}{{end}}'

# Он может монтировать файловую систему хоста:
# docker run -v /etc:/host-etc alpine cat /host-etc/shadow
```

> **Правило:** socket mount = root-доступ к хосту. Используйте только в доверенных CI-средах.

---

## Часть 2 — Docker in Docker (DinD): отдельный daemon

DinD запускает **отдельный Docker daemon** внутри контейнера. Полная изоляция от хоста, но требует `--privileged`.

```text
┌─────────────────────────────────────────┐
│            Хост (Docker daemon)         │
│                                         │
│  ┌──────────────────────────────┐       │
│  │ DinD-контейнер (privileged)  │       │
│  │  ┌─────────────────────┐     │       │
│  │  │ Docker daemon #2    │     │       │
│  │  │  ┌──────────┐       │     │       │
│  │  │  │ child    │       │     │       │
│  │  │  │ container│       │     │       │
│  │  │  └──────────┘       │     │       │
│  │  └─────────────────────┘     │       │
│  └──────────────────────────────┘       │
└─────────────────────────────────────────┘
```

### Практика

```bash
docker compose -f lab/dind/compose.yaml up -d

# Подождать пока DinD daemon стартует (3-5 секунд)
sleep 5

# Docker CLI внутри DinD-контейнера видит ТОЛЬКО свой daemon
docker compose -f lab/dind/compose.yaml exec dind \
  docker info
# Server Version: 27.x.x
# Storage Driver: overlay2

# Он не видит контейнеры хоста
docker compose -f lab/dind/compose.yaml exec dind \
  docker ps
# CONTAINER ID  IMAGE  COMMAND  ...  (пусто — свой daemon, своё пространство)

# Собираем образ внутри DinD
docker compose -f lab/dind/compose.yaml exec dind \
  docker build -t internal-app /workspace

# Запускаем контейнер внутри DinD
docker compose -f lab/dind/compose.yaml exec dind \
  docker run --rm internal-app

docker compose -f lab/dind/compose.yaml down -v
```

### DinD: --privileged объяснение

```bash
# --privileged снимает ВСЕ security-ограничения:
# - Доступ ко всем capabilities
# - Доступ к /dev устройствам хоста
# - Отключение seccomp, AppArmor
# - Маунт cgroup filesystem

# Проверить privileged-статус
docker inspect $(docker compose -f lab/dind/compose.yaml ps -q dind) \
  --format '{{.HostConfig.Privileged}}'
# true
```

---

## Часть 3 — Socket mount vs DinD: сравнение

| Критерий | Socket mount | DinD (privileged) |
|---|---|---|
| Изоляция | Нет — шарит daemon хоста | Да — свой daemon |
| Безопасность | Root-доступ к хосту | Privileged-режим |
| Скорость | Быстрее (layer cache хоста) | Медленнее (холодный кеш) |
| Сложность | Одна строка в compose | Нужен entrypoint, сертификаты |
| Persistence | Образы остаются на хосте | Образы исчезают при рестарте |
| Использование | Jenkins, GitLab CI | Kubernetes CI, изолированные билды |

### Третий путь: Sysbox

```bash
# Sysbox — runtime, который позволяет запускать Docker-in-Docker
# БЕЗ --privileged. Использует user namespaces.

# Установка (Linux):
# curl -fsSL https://github.com/nestybox/sysbox/releases/download/v0.6.5/sysbox-ce_0.6.5-0.linux_amd64.deb -o sysbox.deb
# sudo dpkg -i sysbox.deb

# Запуск без privileged:
# docker run --runtime=sysbox-runc -d docker:27-dind
```

---

## Часть 4 — Testcontainers: настоящие зависимости в тестах

Testcontainers — библиотека для запуска Docker-контейнеров из integration-тестов. Вместо моков — настоящий PostgreSQL, Redis, Kafka.

```text
Без Testcontainers              С Testcontainers
──────────────────────────────────────────────────
SQLite mock вместо Postgres  →  Настоящий Postgres в контейнере
Тесты не ловят SQL-ошибки   →  Полная совместимость
H2 вместо MySQL              →  Реальный MySQL, реальные типы
Redis mock                    →  Настоящий Redis с TTL
```

### Go: Testcontainers в действии

```bash
# Посмотреть тест
cat lab/testcontainers-go/main_test.go

# Запустить тест (нужен Go 1.24+ и Docker)
cd lab/testcontainers-go
go test -v -count=1 ./...
# === RUN   TestPostgresIntegration
# --- PASS: TestPostgresIntegration (3.42s)
#     main_test.go:45: container started: localhost:55432
#     main_test.go:52: inserted and queried: hello testcontainers
```

### Что делает тест

```go
// 1. Создаёт Postgres-контейнер
container, err := postgres.Run(ctx,
    "postgres:16-alpine",
    postgres.WithDatabase("testdb"),
    postgres.WithUsername("test"),
    postgres.WithPassword("test"),
    testcontainers.WithWaitStrategy(
        wait.ForLog("database system is ready to accept connections").
            WithOccurrence(2).WithStartupTimeout(30*time.Second),
    ),
)

// 2. Получает connection string
connStr, _ := container.ConnectionString(ctx, "sslmode=disable")

// 3. Делает запросы к РЕАЛЬНОЙ PostgreSQL
db.Exec("CREATE TABLE notes (text TEXT)")
db.Exec("INSERT INTO notes VALUES ($1)", "hello testcontainers")

// 4. Контейнер автоматически уничтожается после теста
defer container.Terminate(ctx)
```

### Python: Testcontainers

```bash
cat lab/testcontainers-python/test_redis.py

# Запустить (нужен Python 3.12+ и Docker)
cd lab/testcontainers-python
pip install -r requirements.txt
pytest -v test_redis.py
# PASSED test_redis.py::test_redis_set_get
```

---

## Часть 5 — Testcontainers в CI: socket mount обязателен

```yaml
# .github/workflows/integration-test.yml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.24'
      - name: Integration tests
        run: go test -v -count=1 ./...
        # На GitHub Actions Docker уже установлен.
        # Testcontainers автоматически используют /var/run/docker.sock.
```

```yaml
# GitLab CI: нужен DinD-сервис
integration-test:
  image: golang:1.24
  services:
    - docker:27-dind
  variables:
    DOCKER_HOST: tcp://docker:2376
    DOCKER_TLS_CERTDIR: "/certs"
    TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE: /var/run/docker.sock
    TESTCONTAINERS_HOST_OVERRIDE: docker
  script:
    - go test -v -count=1 ./...
```

---

## Часть 6 — Broken: неправильный socket mount

```bash
# Сценарий 1: сокет примонтирован, но нет docker CLI
docker compose -f broken/compose-no-cli.yaml up -d
docker compose -f broken/compose-no-cli.yaml exec runner \
  docker ps
# sh: docker: not found  ← в образе нет docker CLI

docker compose -f broken/compose-no-cli.yaml down
```

```bash
# Сценарий 2: неправильные права на сокет
docker compose -f broken/compose-wrong-perms.yaml up -d
docker compose -f broken/compose-wrong-perms.yaml exec runner \
  docker ps
# permission denied while trying to connect to the Docker daemon socket
# Fix: добавить user в группу docker или запустить от root

docker compose -f broken/compose-wrong-perms.yaml down
```

```bash
# Сценарий 3: DinD без --privileged
docker compose -f broken/compose-dind-no-priv.yaml up -d
sleep 3
docker compose -f broken/compose-dind-no-priv.yaml logs dind
# iptables/permission denied — daemon не может стартовать

docker compose -f broken/compose-dind-no-priv.yaml down
```

---

## Типовые ошибки

| Ошибка | Симптом | Исправление |
|---|---|---|
| Socket mount без docker CLI в контейнере | `docker: not found` | Использовать образ `docker:27-cli` или установить CLI |
| Socket mount от non-root без группы docker | `permission denied` | `user: root` или `group_add: [docker]` в compose |
| DinD без `--privileged` | `iptables: Permission denied` | Добавить `privileged: true` |
| DinD без volume для layer cache | Каждая сборка с нуля | Volume на `/var/lib/docker` |
| Testcontainers: `DOCKER_HOST` не настроен | `Cannot connect to Docker daemon` | Проверить socket mount или `DOCKER_HOST` |
| Testcontainers: порт коллизия | Контейнеры конфликтуют | TC используют рандомные порты автоматически |

---

## Вопросы для самопроверки

1. Почему socket mount — это фактически root-доступ к хосту?
2. Чем DinD-изоляция лучше socket mount? В чём её минусы?
3. Что такое `--privileged` и какие ограничения он снимает?
4. Как Testcontainers решают проблему «у меня другая версия Postgres»?
5. Почему Sysbox безопаснее классического DinD?
6. Как настроить Testcontainers в GitLab CI с DinD-сервисом?
7. Что произойдёт с контейнерами, созданными через socket mount, при смерти CI-контейнера?
8. Почему Testcontainers используют рандомные порты, а не фиксированные?

---

## Файлы модуля

| Файл | Назначение |
|---|---|
| `lab/socket-mount/` | CI-runner с socket mount |
| `lab/dind/` | Docker-in-Docker стенд |
| `lab/testcontainers-go/` | Go integration test с Postgres |
| `lab/testcontainers-python/` | Python integration test с Redis |
| `broken/compose-no-cli.yaml` | Сокет без CLI |
| `broken/compose-wrong-perms.yaml` | Неверные права |
| `broken/compose-dind-no-priv.yaml` | DinD без privileged |

## Cleanup

```bash
./cleanup.sh
```
