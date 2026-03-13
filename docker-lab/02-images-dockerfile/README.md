# 02. Images и Dockerfile

## Цель

Научиться собирать образ предсказуемо: быстрый билд, чистые слои, понятный runtime.

---

## Теория

### Инструкции Dockerfile

| Инструкция  | Назначение                                                         |
|-------------|---------------------------------------------------------------------|
| `FROM`      | Базовый образ. Используйте конкретную версию, а не `latest`         |
| `WORKDIR`   | Рабочая директория — создаёт путь автоматически                     |
| `COPY`      | Копирует файлы в слой. Предпочесть `ADD` нельзя без причины         |
| `RUN`       | Выполняет команду и создаёт слой                                    |
| `ENV`       | Переменная окружения — видна в рантайме и дочерних образах          |
| `ARG`       | Переменная только для сборки — в рантайме недоступна                |
| `EXPOSE`    | Документирует порт (не открывает его)                               |
| `USER`      | Переключает пользователя для последующих инструкций и CMD/ENTRYPOINT|
| `HEALTHCHECK` | Docker проверяет живость процесса изнутри контейнера              |
| `CMD`       | Команда по умолчанию — можно переопределить при `docker run`        |
| `ENTRYPOINT`| Точка входа — принимает аргументы из CMD                            |

### ARG vs ENV: ключевая разница

```dockerfile
ARG BUILD_DATE          # доступен только во время docker build
ENV APP_PORT=8090       # доступен внутри контейнера в рантайме

# ОПАСНО: секрет через ARG виден в docker history!
ARG SECRET_KEY          # ← не делайте так
RUN call_api.sh $SECRET_KEY
```

Правило: **секреты не должны попадать ни в ARG, ни в ENV**.

### Порядок инструкций = скорость кеша

```dockerfile
# ✅ Правильно: зависимости копируем отдельно до исходников
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py ./

# ❌ Неправильно: любое изменение app.py сбрасывает кеш pip
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
```

### .dockerignore — обязателен

Без `.dockerignore` build context включает `.git`, `node_modules`, `.env`,
виртуальные окружения и временные файлы. Это замедляет сборку и может утечь секреты.

```gitignore
# .dockerignore
.git
.gitignore
__pycache__
*.pyc
*.pyo
.env
.env.*
venv/
.venv/
*.log
tests/
docs/
```

Проверьте, что реально уходит в контекст:
```bash
docker build --no-cache -t test . 2>&1 | grep "Sending build context"
```

### HEALTHCHECK — докер знает о живости изнутри

```dockerfile
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8090/healthz')" \
  || exit 1
```

- `--start-period` — grace период после запуска, не считается как failure
- `--retries` — сколько раз должен упасть, чтобы стать `unhealthy`
- `exit 1` явно — без него Python исключение не транслируется в код ошибки

### dumb-init: PID 1 и сигналы

В Docker контейнер должен корректно обрабатывать `SIGTERM` (посылает `docker stop`).
Обычный процесс приложения не обрабатывает сигналы зомби-процессов.

```dockerfile
RUN pip install dumb-init
ENTRYPOINT ["dumb-init", "--"]
CMD ["python", "app.py"]
```

Или с системным пакетом:
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends dumb-init \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["python", "app.py"]
```

`dumb-init` корректно форвардит сигналы и собирает зомби-процессы.

### CMD vs ENTRYPOINT

```dockerfile
# Только CMD — легко переопределить
CMD ["python", "app.py"]
# docker run myimage python other.py   ← переопределяет полностью

# ENTRYPOINT + CMD — CMD становится аргументами
ENTRYPOINT ["python"]
CMD ["app.py"]
# docker run myimage other.py         ← подставляет 'other.py' как аргумент
```

**Правило:** для сервисов используйте `ENTRYPOINT ["dumb-init", "--"]` + `CMD`.

---

## Практика

### 1. Создайте .dockerignore

```bash
cat > lab/.dockerignore << 'EOF'
__pycache__
*.pyc
.env
.env.*
*.log
EOF
```

### 2. Соберите образ и проверьте кеш

```bash
docker build -t dockerlab/simple-web:dev ./lab
# Второй запуск — все слои из кеша:
docker build -t dockerlab/simple-web:dev ./lab
```

### 3. Запустите контейнер

```bash
docker run --rm -p 8090:8090 dockerlab/simple-web:dev
```

### 4. Проверьте приложение

```bash
curl http://localhost:8090/healthz
```

### 5. Проверьте пользователя и слои

```bash
# От какого пользователя запущен процесс?
docker inspect dockerlab/simple-web:dev --format '{{.Config.User}}'

# История слоёв и их размеры
docker history dockerlab/simple-web:dev

# Полный список слоёв с ID
docker inspect dockerlab/simple-web:dev --format '{{json .RootFS.Layers}}' | python -m json.tool
```

### 6. Найдите утечку секретов через ARG

```bash
# Соберите образ с ARG-секретом
docker build --build-arg SECRET=mysecret -t test-secret - << 'EOF'
FROM alpine
ARG SECRET
RUN echo "doing something with $SECRET"
EOF

# Теперь проверьте history — секрет виден!
docker history test-secret --no-trunc | grep SECRET
docker image rm test-secret
```

### 7. Сравните с broken/Dockerfile.bad

```bash
docker build -t dockerlab/simple-web:bad ./broken
docker history dockerlab/simple-web:dev   # сколько слоёв? какой размер?
docker history dockerlab/simple-web:bad
```

---

## Проверка

- Образ собирается с кешем: повторный `docker build` использует cached слои.
- Процесс внутри контейнера запускается от non-root пользователя.
- `.dockerignore` присутствует и исключает ненужные файлы.
- Понимаете разницу `CMD` и `ENTRYPOINT`.
- Можете объяснить, почему `ARG SECRET` — уязвимость.

---

## Типовые ошибки

| Ошибка | Последствие | Исправление |
|--------|-------------|-------------|
| `COPY . .` до `pip install` | Инвалидация кеша при любом изменении | Сначала `COPY requirements.txt`, потом исходники |
| Большой build context без `.dockerignore` | Медленный билд, утечка `.env` | Создать `.dockerignore` |
| Секрет в `ARG` или `ENV` | Виден в `docker history`, логах | Передавать через runtime env или volume |
| `CMD ["python", "app.py"]` без init | Зомби-процессы, неправильный `docker stop` | Добавить `dumb-init` |
| Нет `HEALTHCHECK` | Docker не знает о состоянии приложения | Добавить `HEALTHCHECK CMD ...` |

---

## Вопросы

1. Как перестановка `COPY` влияет на скорость билда?
2. Почему `.dockerignore` обязателен даже в "безопасных" проектах?
3. Когда выбирать `ENTRYPOINT`, а когда `CMD`?
4. Чем `ARG` отличается от `ENV`? Почему секрет через `ARG` небезопасен?
5. Что делает `dumb-init`? В чём проблема с PID 1 без init-процесса?

---

## Дополнительные задания

- Добавьте build-arg `APP_VERSION` и выводите его в `/healthz`.
- Сравните размер образа `python:3.12` vs `python:3.12-slim` vs `python:3.12-alpine`.
- Напишите `.dockerignore` для Node.js проекта (исключите `node_modules`, `.next`, `dist`).
- Добавьте `HEALTHCHECK` и проследите, как меняется вывод `docker ps`.

---

## Файлы модуля

- `lab/` — рабочий Dockerfile и минимальное web-приложение.
- `broken/Dockerfile.bad` — анти-паттерны: root, плохой порядок, нет `.dockerignore`.
- `broken/CHALLENGES.md` — 8 сломанных Dockerfile с подсказками под спойлером.
- `checks/verify.sh` — smoke-проверка образа.

## Cleanup

```bash
./cleanup.sh
```
