# 08. Advanced build: multi-stage, buildx, cache

## Зачем это важно

Неоптимальный Dockerfile — это медленные CI-сборки, огромные образы с лишними инструментами и ненужными CVE. Multi-stage build решает эти проблемы структурно.

```text
Single-stage:   [golang:1.24]  →  образ ~900 MB (SDK + исходники + бинарник)
Multi-stage:    [golang:1.24]  →  [distroless]  →  образ ~8 MB (только бинарник)
```

---

## Часть 1 — Проблема: single-stage Dockerfile

```bash
# Собрать толстый single-stage образ
docker build -t dockerlab/go-api:single -f broken/Dockerfile.single ./lab

# Размер
docker image ls dockerlab/go-api:single --format 'size: {{.Size}}'
# ~900 MB — полный Go SDK в образе

# Что внутри? Весь тулчейн
docker run --rm dockerlab/go-api:single go version
# go version go1.22... — SDK в production-образе
docker run --rm dockerlab/go-api:single ls /usr/local/go/bin/
# go, gofmt, ... — не нужны в runtime

# Attack surface
docker run --rm aquasec/trivy:latest image \
  --severity HIGH,CRITICAL dockerlab/go-api:single
# Много CVE от golang:1.24
```

---

## Часть 2 — Multi-stage build

Ключевая идея: **builder** — большой, содержит SDK и dev-зависимости. **runtime** — только то, что нужно для запуска.

```dockerfile
# Стадия 1: builder — компилируем
FROM golang:1.24-alpine AS builder
WORKDIR /src
COPY src/go.mod ./
RUN go mod download          # кешируемый слой
COPY src/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/app ./main.go

# Стадия 2: runtime — только бинарник
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

```bash
# Собрать multi-stage образ
docker build -t dockerlab/go-api:dev ./lab

# Размер
docker image ls dockerlab/go-api:dev --format 'size: {{.Size}}'
# ~8 MB

# SDK внутри есть?
docker run --rm dockerlab/go-api:dev go version
# OCI runtime error — нет go, нет shell вообще (distroless)

# Приложение работает
docker run -d --name api-test -p 8084:8084 dockerlab/go-api:dev
curl http://localhost:8084/healthz
# ok
docker rm -f api-test
```

---

## Часть 3 — Кеширование слоёв: порядок имеет значение

Docker кеширует слои. Если слой изменился — все последующие пересобираются. Выгодно класть медленные, редко меняющиеся операции раньше.

```dockerfile
# Плохо: изменение любого .go файла инвалидирует go mod download
COPY src/ ./
RUN go mod download

# Хорошо: go.mod меняется редко — кешируем отдельно
COPY src/go.mod ./
RUN go mod download       # ← этот слой переиспользуется, если go.mod не менялся
COPY src/ ./              # ← только здесь копируем код
```

```bash
# Первая сборка — холодный кеш
time docker build -t dockerlab/go-api:dev ./lab
# real 0m45s

# Изменим только исходный код (не go.mod)
echo '// comment' >> lab/src/main.go

# Вторая сборка — go mod download из кеша
time docker build -t dockerlab/go-api:dev ./lab
# real 0m4s  ← в 10 раз быстрее

# Откатим изменение
git checkout lab/src/main.go 2>/dev/null || sed -i '$ d' lab/src/main.go
```

---

## Часть 4 — Build targets: несколько образов из одного Dockerfile

`--target` останавливает сборку на указанной стадии. Полезно для dev/test/prod из одного файла.

```dockerfile
FROM golang:1.24-alpine AS builder
# ... компиляция ...

FROM builder AS dev            # наследует builder — есть shell и инструменты
RUN go install github.com/air-verse/air@latest
CMD ["air"]                    # hot-reload для разработки

FROM gcr.io/distroless/static-debian12:nonroot AS prod
COPY --from=builder /out/app /app
ENTRYPOINT ["/app"]
```

```bash
# Собрать только builder-стадию (для CI-проверок)
docker build --target builder -t dockerlab/go-api:builder ./lab

# Войти в builder чтобы запустить тесты
docker run --rm dockerlab/go-api:builder go test ./...
```

---

## Часть 5 — Buildx: multi-platform сборка

Один образ — две архитектуры. Актуально для Mac M-серии (arm64) и серверов (amd64).

```bash
# Создать buildx builder (один раз)
docker buildx create --name multiarch --use --bootstrap

# Проверить доступные платформы
docker buildx ls

# Сборка под несколько платформ (требует registry для --push)
# Вместо реального registry — смотрим что buildx умеет:
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag dockerlab/go-api:multiarch \
  --load \     # загрузить только текущую платформу локально
  ./lab

# Проверить платформу текущего образа
docker inspect dockerlab/go-api:dev \
  --format '{{.Os}}/{{.Architecture}}'
# linux/amd64  (или arm64 на Mac M-серии)
```

---

## Часть 6 — Сравнение образов

```bash
# Собрать оба варианта
docker build -t dockerlab/go-api:single -f broken/Dockerfile.single ./lab
docker build -t dockerlab/go-api:dev ./lab

# Размер
docker image ls dockerlab/go-api --format 'table {{.Tag}}\t{{.Size}}'
# TAG      SIZE
# dev      8.2MB
# single   918MB

# Количество слоёв
docker history dockerlab/go-api:dev    | wc -l
docker history dockerlab/go-api:single | wc -l

# CVE
docker run --rm aquasec/trivy:latest image --severity HIGH,CRITICAL dockerlab/go-api:dev
docker run --rm aquasec/trivy:latest image --severity HIGH,CRITICAL dockerlab/go-api:single
# dev: 0 CVE (distroless)
# single: N CVE (полный golang SDK)
```

---

## Типовые ошибки

| Ошибка | Последствие | Исправление |
|---|---|---|
| `COPY . .` перед `go mod download` | Кеш инвалидируется при любом изменении кода | Сначала `COPY go.mod`, потом `COPY .` |
| `CGO_ENABLED=1` при сборке в distroless | Бинарник ищет glibc, которой нет | `CGO_ENABLED=0` для статической линковки |
| Нет `AS` в FROM | Нельзя использовать `--target` и `--from` | Именовать все стадии |
| `COPY . .` копирует `.git`, `node_modules` | Образ больше, кеш ломается | Добавить `.dockerignore` |

---

## Вопросы для самопроверки

1. Почему `COPY go.mod ./` + `RUN go mod download` нужно делать до `COPY . .`?
2. Что происходит с файлами builder-стадии в финальном образе?
3. Чем `distroless` лучше `alpine` для production Go-бинарника?
4. Зачем `CGO_ENABLED=0` при сборке под distroless?
5. Как запустить тесты внутри builder-стадии без копирования тестового кода в финальный образ?
6. Что такое `.dockerignore` и что туда обязательно добавить?

---

## Cleanup

```bash
./cleanup.sh
```
