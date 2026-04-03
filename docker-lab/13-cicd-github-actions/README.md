# 13. CI/CD: GitLab CI/CD + Container Registry

## Что делает этот модуль

Настроен реальный CI/CD pipeline для GitLab. При пуше в `main` или создании тега `v*` запускается:

```text
Lint → Build + Smoke Test → Scan (Trivy) → Push to Registry
```

Pipeline-файл: [lab/gitlab-ci/.gitlab-ci.yml](lab/gitlab-ci/.gitlab-ci.yml)

Приложение: [lab/](lab/) — Go HTTP-сервер с `/healthz`

---

## Структура pipeline

```text
on: push main / tag v* / ручной запуск
              │
        ┌─────▼─────┐
        │   lint    │  hadolint → качество Dockerfile
        └─────┬─────┘
              │ needs: lint
        ┌─────▼──────────┐
        │  build         │  docker build → smoke test /healthz → сохранить image.tar
        └─────┬──────────┘
              │ needs: build
        ┌─────▼─────┐
        │   scan    │  trivy → EXIT 1 при HIGH/CRITICAL CVE
        └─────┬─────┘
              │ needs: [build, scan]
              │ rules: только main и теги v*
        ┌─────▼─────┐
        │   push    │  push sha-тег + latest/semver в Container Registry
        └───────────┘
```

---

## Часть 1 — Подготовка GitLab-проекта

### 1.1 Создать проект и форкнуть репозиторий

```bash
# Вариант А: создать новый GitLab-проект и скопировать lab/
git clone https://gitlab.com/<your-username>/my-app.git
cp -r docker-lab/13-cicd-github-actions/lab/* my-app/
cd my-app
cp docker-lab/13-cicd-github-actions/examples/gitlab-ci-template.yml .gitlab-ci.yml
git add .
git commit -m "ci: add GitLab CI/CD pipeline"
git push origin main
```

```bash
# Вариант Б: использовать этот репозиторий напрямую
# Загрузи репозиторий в GitLab (mirror или новый remote):
git remote add gitlab https://gitlab.com/<your-username>/lern.git
git push gitlab main
```

### 1.2 Настроить путь к pipeline-файлу (для Варианта Б)

Если `.gitlab-ci.yml` не в корне репозитория:

1. GitLab → проект → **Settings → CI/CD → General pipelines**
2. **CI/CD configuration file**: вставить путь:

```text
docker-lab/13-cicd-github-actions/lab/gitlab-ci/.gitlab-ci.yml
```

3. Сохранить.

### 1.3 Включить Container Registry

1. GitLab → проект → **Settings → General → Visibility**
2. Найти **Container Registry** → включить
3. После включения: **Deploy → Container Registry** появится в меню

### 1.4 Настроить GitLab Runner

GitLab.com — shared runners уже включены (достаточно для обучения).

Для self-hosted GitLab:

```bash
# Установить runner на свою машину
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install gitlab-runner

# Зарегистрировать runner
sudo gitlab-runner register \
  --url https://gitlab.com \
  --token <registration-token> \      # Settings → CI/CD → Runners → New runner
  --executor docker \
  --docker-image docker:27 \
  --docker-privileged               # обязательно для Docker-in-Docker
```

---

## Часть 2 — Запустить pipeline

### Триггер через коммит в main

```bash
# Любое изменение в lab/
echo "// updated" >> lab/main.go
git add lab/main.go
git commit -m "ci: trigger pipeline"
git push origin main
```

Открой: **Build → Pipelines** → смотри stages и логи каждого job.

### Триггер через тег (релиз)

```bash
git tag v1.0.0
git push origin v1.0.0
```

После успешного pipeline образ появится в Registry:

```text
registry.gitlab.com/<namespace>/<project>:1.0.0
registry.gitlab.com/<namespace>/<project>:1.0
registry.gitlab.com/<namespace>/<project>:sha-abc1234
```

### Ручной запуск

**Build → Pipelines → Run pipeline** → выбрать ветку → **Run pipeline**.

---

## Часть 3 — Разобрать каждый job

### job: lint

```yaml
lint:
  image: hadolint/hadolint:v2.12.0-alpine
  script:
    - hadolint Dockerfile --failure-threshold warning
```

```bash
# То же самое локально
docker run --rm -i hadolint/hadolint < lab/Dockerfile
# Нет вывода = нет ошибок
```

Что проверяет hadolint:

| Код | Проблема |
|---|---|
| DL3007 | `FROM image:latest` — не pinned |
| DL3009 | `RUN apt-get update` без `install` в том же слое |
| DL3020 | `ADD` вместо `COPY` |
| DL3042 | `pip install` без `--no-cache-dir` |

### job: build

```yaml
build:
  image: docker:27
  services:
    - name: docker:27-dind
      alias: docker
  script:
    - docker build -t $IMAGE_SHA .
    - docker run -d --name smoke $IMAGE_SHA
    - SMOKE_IP=$(docker inspect smoke --format '{{.NetworkSettings.IPAddress}}')
    - curl --fail --retry 5 http://$SMOKE_IP:8080/healthz
    - docker save $IMAGE_SHA -o image.tar
  artifacts:
    paths: [image.tar]
    expire_in: 1 hour
```

**Почему `docker inspect` вместо `-p 8080:8080`:**
В режиме DinD Docker-демон работает внутри service-контейнера. Порт-маппинг (`-p`) прокидывает порт на DinD-хост, а не на runner-хост. Прямое подключение по IP контейнера надёжнее.

**`image.tar`** — артефакт: образ сохраняется как файл и передаётся в следующие jobs. Без этого каждый job собирал бы образ заново.

```bash
# Локально: собрать и проверить
docker build -t cicd-app:test docker-lab/13-cicd-github-actions/lab
docker run -d --name smoke -p 8080:8080 cicd-app:test
curl http://localhost:8080/healthz   # ok
docker rm -f smoke
```

### job: scan

```yaml
scan:
  image:
    name: aquasec/trivy:latest
    entrypoint: [""]   # отключить собственный entrypoint
  script:
    - trivy image
        --input image.tar    # читает из артефакта, Docker не нужен
        --exit-code 1
        --severity HIGH,CRITICAL
        --ignore-unfixed
```

**`entrypoint: [""]`** — без этого GitLab не может запустить `script`, потому что `aquasec/trivy` имеет свой entrypoint.

**`--input image.tar`** — Trivy анализирует сохранённый `.tar` без запущенного Docker-демона.

```bash
# Локально
docker run --rm aquasec/trivy:latest image \
  --severity HIGH,CRITICAL --ignore-unfixed cicd-app:test
# 0 vulnerabilities (distroless + Go 1.24)
```

### job: push

```yaml
push:
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH   # main
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/     # v1.2.3
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker push $IMAGE_SHA
```

**Переменные GitLab, заполняемые автоматически:**

| Переменная | Значение |
|---|---|
| `CI_REGISTRY` | `registry.gitlab.com` |
| `CI_REGISTRY_USER` | логин для push |
| `CI_REGISTRY_PASSWORD` | токен для push |
| `CI_REGISTRY_IMAGE` | `registry.gitlab.com/<ns>/<project>` |
| `CI_COMMIT_SHORT_SHA` | первые 8 символов SHA коммита |
| `CI_DEFAULT_BRANCH` | имя main-ветки (`main`) |

---

## Часть 4 — Docker-in-Docker (DinD)

```yaml
variables:
  DOCKER_HOST: tcp://docker:2376
  DOCKER_TLS_CERTDIR: "/certs"

services:
  - name: docker:27-dind
    alias: docker
```

**Как это работает:**

```text
GitLab Runner (host)
  └── Job container  (docker:27)
        │  DOCKER_HOST=tcp://docker:2376
        └── DinD service  (docker:27-dind)
              └── Docker daemon → собирает образ
```

Runner запускает два контейнера: основной (где выполняется `script`) и сервисный (где работает Docker-демон). Переменная `DOCKER_HOST` направляет Docker CLI в основном контейнере к демону в сервисном.

**Почему TLS:**

`DOCKER_TLS_CERTDIR: "/certs"` — Docker-демон и CLI обмениваются сертификатами через volume `/certs`. Без TLS используй `DOCKER_TLS_CERTDIR: ""` и `tcp://docker:2375`, но это небезопасно.

**Почему runner должен быть `--privileged`:**

DinD требует возможности создавать namespace'ы и управлять cgroups. Без `--privileged` сборка упадёт с ошибкой `operation not permitted`.

---

## Часть 5 — Тегирование образов

```yaml
IMAGE_SHA: $CI_REGISTRY_IMAGE:sha-$CI_COMMIT_SHORT_SHA
```

```bash
# push в main → sha-тег + latest
registry.gitlab.com/user/project:sha-abc1234
registry.gitlab.com/user/project:latest

# git tag v1.3.0 → sha-тег + semver
registry.gitlab.com/user/project:sha-abc1234
registry.gitlab.com/user/project:1.3.0
registry.gitlab.com/user/project:1.3
```

Логика тегирования в `push` job:

```bash
# sha — всегда (иммутабельный, по нему можно точно воспроизвести билд)
docker push $IMAGE_SHA

# latest — только из main
if [ "$CI_COMMIT_BRANCH" = "$CI_DEFAULT_BRANCH" ]; then
  docker tag $IMAGE_SHA $CI_REGISTRY_IMAGE:latest
  docker push $CI_REGISTRY_IMAGE:latest
fi

# semver — при git tag
if [ -n "$CI_COMMIT_TAG" ]; then
  VERSION="${CI_COMMIT_TAG#v}"   # v1.3.0 → 1.3.0
  MINOR="${VERSION%.*}"          # 1.3.0  → 1.3
  docker tag $IMAGE_SHA $CI_REGISTRY_IMAGE:$VERSION
  docker tag $IMAGE_SHA $CI_REGISTRY_IMAGE:$MINOR
  docker push $CI_REGISTRY_IMAGE:$VERSION
  docker push $CI_REGISTRY_IMAGE:$MINOR
fi
```

| Событие | Теги образа |
|---|---|
| `push` в `main` | `latest`, `sha-abc1234` |
| `git tag v1.3.0` | `1.3.0`, `1.3`, `sha-abc1234` |
| `push` в feature-ветку | pipeline не запускает push job |

---

## Часть 6 — rules: управление триггерами

```yaml
# Запускать pipeline только при изменениях в нужных файлах
workflow:
  rules:
    - changes:
        - lab/**/*
        - .gitlab-ci.yml
    - if: $CI_PIPELINE_SOURCE == "web"   # ручной запуск
```

```yaml
# Job выполняется только при коммите в main или при теге
push:
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
```

**Разница `rules:` vs `only/except:`:**

`rules:` — современный синтаксис, более гибкий. `only/except:` — устаревший.

---

## Часть 7 — needs: (DAG вместо линейных stage)

```yaml
scan:
  needs:
    - job: build
      artifacts: true   # скачать image.tar

push:
  needs:
    - job: build
      artifacts: true   # image.tar
    - job: scan
      artifacts: false  # только ждём успеха
```

**`needs:` vs `stage:`:**

- Без `needs:` — job ждёт завершения всех jobs предыдущего stage
- С `needs:` — job стартует сразу после указанных jobs (DAG), независимо от stage

`artifacts: true/false` в needs — управляет, какие артефакты скачиваются в этот job.

---

## Часть 8 — Переменные CI/CD

### Просмотр всех предопределённых переменных

```yaml
# Добавь временный job в pipeline
debug-vars:
  stage: lint
  script:
    - export | grep CI_
```

### Добавить свои переменные

**GitLab → Settings → CI/CD → Variables → Add variable:**

| Переменная | Пример значения | Masked | Protected |
|---|---|---|---|
| `TRIVY_TOKEN` | ghp_xxx | да | нет |
| `SLACK_WEBHOOK` | https://hooks... | да | нет |
| `DEPLOY_ENV` | production | нет | да |

**Protected** — доступна только в protected branches/tags.
**Masked** — скрыта в логах (нельзя прочитать в выводе job).

---

## Часть 9 — Посмотреть образ в Registry

```bash
# После успешного pipeline
docker pull registry.gitlab.com/<username>/<project>:latest
docker run --rm registry.gitlab.com/<username>/<project>:latest
# hello from <hostname>

# Проверить теги
docker buildx imagetools inspect registry.gitlab.com/<username>/<project>:latest
```

Через UI: **Deploy → Container Registry** — список всех тегов с размером и датой.

---

## Часть 10 — Адаптировать под свой проект

```bash
# Скопировать шаблон в корень нового GitLab-проекта
cp docker-lab/13-cicd-github-actions/examples/gitlab-ci-template.yml \
   /path/to/my-project/.gitlab-ci.yml

# Отредактировать переменные в начале файла:
# APP_PORT: 3000     (порт твоего приложения)
```

Шаблон: [examples/gitlab-ci-template.yml](examples/gitlab-ci-template.yml)

---

## Типовые ошибки

| Ошибка | Симптом | Причина и fix |
|---|---|---|
| `Cannot connect to the Docker daemon` | build job упадёт | Runner не `--privileged` или нет сервиса `docker:27-dind` |
| `curl: (7) Failed to connect to localhost` | smoke test упадёт | Используй IP контейнера, а не `localhost` в DinD |
| `unauthorized: authentication required` | push упадёт | Container Registry отключён или job не имеет прав |
| `Error response from daemon: pull access denied` | build упадёт | Образ приватный, нужен `docker login` перед `docker build` |
| `trivy: exit status 1` | scan упадёт | Найдена HIGH/CRITICAL CVE — обнови образ или добавь `.trivyignore` |
| `entrypoint:` не указан для Trivy | `exec: "trivy": not found` | Добавь `entrypoint: [""]` в image блок |
| `image.tar not found` | scan/push упадут | `artifacts` в build job не настроены или `expire_in` истёк |
| `needs: job 'build' is not defined` | pipeline не запустится | Проверь имя job в `needs:` — должно точно совпадать |

---

## Вопросы для самопроверки

1. Зачем `DOCKER_TLS_CERTDIR: "/certs"` — что произойдёт без него?
2. Почему smoke test использует IP контейнера, а не `localhost`?
3. `image.tar` — как передаётся между jobs? Где хранится?
4. `needs:` vs `stage:` — в чём разница в порядке выполнения?
5. `entrypoint: [""]` для Trivy — почему это необходимо?
6. Почему `latest` не должен пушиться из feature-веток?
7. `--privileged` runner — какие риски безопасности это несёт?
8. Как получить digest образа после push и закрепить его в манифесте деплоя?

---

## Файлы модуля

| Файл | Назначение |
|---|---|
| [lab/Dockerfile](lab/Dockerfile) | Multi-stage сборка Go → distroless |
| [lab/main.go](lab/main.go) | Go HTTP-сервер с `/healthz` и `/` |
| [lab/go.mod](lab/go.mod) | Go module |
| [lab/gitlab-ci/.gitlab-ci.yml](lab/gitlab-ci/.gitlab-ci.yml) | Pipeline для этого монорепо |
| [examples/gitlab-ci-template.yml](examples/gitlab-ci-template.yml) | Шаблон для своего проекта |

## Cleanup

```bash
./cleanup.sh
```
