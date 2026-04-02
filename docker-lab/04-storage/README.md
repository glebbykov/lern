# 04. Storage: volumes, bind mounts, tmpfs

## Зачем это важно

Контейнер по умолчанию **эфемерен**: его файловая система живёт ровно столько, сколько живёт сам контейнер. Удалил контейнер — данные исчезли. Docker предоставляет три механизма, чтобы данные пережили контейнер или были доступны снаружи.

## Типы хранилищ

| Тип | Где хранится | Кто управляет | Типичный сценарий |
|---|---|---|---|
| **Named volume** | `/var/lib/docker/volumes/` | Docker | БД, очереди, постоянные данные |
| **Bind mount** | Любое место на хосте | Пользователь | Dev: горячая перезагрузка кода/конфигов |
| **tmpfs** | Память хоста (RAM) | Docker | Секреты, временный кэш, сессии |
| **Anonymous volume** | `/var/lib/docker/volumes/` | Docker | Временные данные из `VOLUME` в Dockerfile |

```text
Хост ФС         Docker Engine        Контейнер
─────────────────────────────────────────────────────────
/home/user/site ──[bind mount]──────► /usr/share/nginx/html
                   [named vol]──────► /var/lib/postgresql/data
                   [tmpfs]──────────► /run/secrets
```

---

## Часть 1 — Эфемерная ФС: данные исчезают по умолчанию

Запустите PostgreSQL **без** volume, создайте данные, перезапустите — данные пропадут.

```bash
# Запустить PostgreSQL без volume (намеренно сломанная конфигурация)
docker compose -f broken/compose-no-volume.yaml up -d

# Подождать готовности (5-10 сек), затем создать запись
docker compose -f broken/compose-no-volume.yaml exec db \
  psql -U appuser -d appdb -c "CREATE TABLE IF NOT EXISTS notes (text TEXT); INSERT INTO notes VALUES ('важные данные');"

# Проверить — данные есть
docker compose -f broken/compose-no-volume.yaml exec db \
  psql -U appuser -d appdb -c "SELECT * FROM notes;"

# Удалить контейнер
docker compose -f broken/compose-no-volume.yaml down

# Поднять снова и проверить
docker compose -f broken/compose-no-volume.yaml up -d
docker compose -f broken/compose-no-volume.yaml exec db \
  psql -U appuser -d appdb -c "SELECT * FROM notes;"
# ERROR: relation "notes" does not exist — данных нет, таблица не существует
```

**Вывод:** без volume каждый `docker compose down` + `up` — это новый пустой контейнер.

```bash
docker compose -f broken/compose-no-volume.yaml down
```

---

## Часть 2 — Named volume: данные переживают контейнер

Named volume создаётся Docker'ом и хранится в `/var/lib/docker/volumes/<name>/`. Контейнер монтирует директорию из этого volume.

### Запуск

```bash
docker compose -f lab/compose.yaml up -d
```

### Вставить данные

```bash
docker compose -f lab/compose.yaml exec db \
  psql -U appuser -d appdb -c "INSERT INTO notes(text) VALUES ('данные с named volume');"
```

### Убедиться, что данные переживают перезапуск

```bash
# Остановить (БЕЗ -v, иначе volume будет удалён)
docker compose -f lab/compose.yaml down

# Поднять снова
docker compose -f lab/compose.yaml up -d

# Данные на месте
docker compose -f lab/compose.yaml exec db \
  psql -U appuser -d appdb -c "SELECT * FROM notes;"
```

### Inspecting volume

```bash
# Список всех volumes
docker volume ls

# Подробности: точный путь на хосте, driver, размер
docker volume inspect $(docker volume ls -q | grep pg_data)
```

### Backup и restore

```bash
# Создать backup (SQL-дамп)
./lab/scripts/backup.sh

# Удалить данные из БД
docker compose -f lab/compose.yaml exec db \
  psql -U appuser -d appdb -c "TRUNCATE TABLE notes;"

# Восстановить из последнего backup
./lab/scripts/restore.sh

# Проверить
docker compose -f lab/compose.yaml exec db \
  psql -U appuser -d appdb -c "SELECT * FROM notes;"
```

> **Опасность:** `docker compose down -v` удаляет volumes вместе с контейнерами. Всегда делайте backup перед этой командой.

---

## Часть 3 — Bind mount: файлы хоста внутри контейнера

Bind mount монтирует **реальную директорию хоста** прямо в контейнер. Изменения на хосте мгновенно видны внутри контейнера — без перезапуска.

```yaml
volumes:
  - ./site:/usr/share/nginx/html:ro   # :ro = read-only внутри контейнера
```

### Запуск bind-mount стенда

```bash
docker compose -f lab/03-bind-mount/compose.yaml up -d
```

Открой в браузере: <http://localhost:8080>

### Горячее обновление

```bash
# Отредактировать файл на хосте
echo "<h1>Изменено без перезапуска!</h1>" > lab/03-bind-mount/site/index.html

# Обновить страницу в браузере — изменение видно сразу
```

### Посмотреть bind mounts контейнера

```bash
docker inspect $(docker compose -f lab/03-bind-mount/compose.yaml ps -q web) \
  --format '{{ json .Mounts }}' | python3 -m json.tool
```

**Когда использовать:** dev-окружение, конфиги, сертификаты, статика. **Не для продакшн данных БД** — путь привязан к хосту, не переносимо.

```bash
docker compose -f lab/03-bind-mount/compose.yaml down
```

---

## Часть 4 — tmpfs: данные только в памяти

tmpfs монтирует оперативную память хоста как директорию внутри контейнера. Данные **никогда не попадают на диск** и исчезают при остановке контейнера.

```yaml
tmpfs:
  - /run/secrets:size=10m,mode=0700
```

### Запуск tmpfs стенда

```bash
docker compose -f lab/04-tmpfs/compose.yaml up -d
```

### Работа с tmpfs

```bash
# Войти в контейнер
docker compose -f lab/04-tmpfs/compose.yaml exec app sh

# Внутри контейнера:
echo "jwt_secret=super_secret_value" > /run/secrets/token
cat /run/secrets/token          # данные есть
df -h /run/secrets               # видно: tmpfs, нет записи на диск
ls -la /run/secrets

# Выйти
exit

# Перезапустить контейнер
docker compose -f lab/04-tmpfs/compose.yaml restart app

# Войти снова
docker compose -f lab/04-tmpfs/compose.yaml exec app sh
ls /run/secrets    # директория пустая — данные исчезли
exit
```

**Когда использовать:** JWT-секреты, сессионные токены, временные ключи, sensitive кэш. Данные не попадают в слои Docker image и не оседают на диске.

```bash
docker compose -f lab/04-tmpfs/compose.yaml down
```

---

## Часть 5 — Шаринг volume между контейнерами

Один named volume можно подключить к **нескольким контейнерам одновременно**. Это основа sidecar-паттерна (logshipper, backup agent, etc.) и init-контейнеров в Kubernetes.

```yaml
services:
  writer:
    volumes:
      - shared_data:/data
  reader:
    volumes:
      - shared_data:/data   # тот же volume

volumes:
  shared_data:
```

### Запуск sharing стенда

```bash
docker compose -f lab/05-volume-sharing/compose.yaml up -d
```

### Наблюдение за шарингом

```bash
# Смотреть логи reader'а в реальном времени
docker compose -f lab/05-volume-sharing/compose.yaml logs -f reader

# Проверить содержимое shared volume напрямую
docker compose -f lab/05-volume-sharing/compose.yaml exec reader cat /data/log.txt
```

**Вывод:** writer пишет метки времени, reader читает из той же директории — через общий named volume.

```bash
docker compose -f lab/05-volume-sharing/compose.yaml down -v
```

---

## Часть 6 — Управление volumes: CLI

```bash
# Список всех volumes
docker volume ls

# Только named volumes (не anonymous)
docker volume ls --filter name=.

# Подробности: Driver, Mountpoint, Labels
docker volume inspect <volume_name>

# Удалить конкретный volume (контейнер должен быть остановлен)
docker volume rm <volume_name>

# Удалить все неиспользуемые volumes — ОСТОРОЖНО, необратимо
docker volume prune

# Удалить volume вместе с контейнерами
docker compose down -v
```

### Anonymous vs Named volumes

```yaml
# Anonymous: создаётся автоматически из VOLUME в Dockerfile, имя — UUID
# Сложно управлять, легко потерять при docker compose down -v

# Named: явно объявлен в compose.yaml → легко найти, inspect, backup
volumes:
  pg_data:       # named volume — предпочтительный вариант
```

---

## Broken примеры

| Файл | Проблема |
|---|---|
| `broken/compose-no-volume.yaml` | Нет volume → данные эфемерны |
| `broken/compose-wrong-bind.yaml` | Bind mount на несуществующий путь → 403 или пустой сайт |

Запусти и убедись сам:
```bash
# Wrong bind mount: nginx стартует, но отдаёт 403
docker compose -f broken/compose-wrong-bind.yaml up -d
curl http://localhost:8081   # 403 Forbidden — директории нет
docker compose -f broken/compose-wrong-bind.yaml down
```

---

## Сравнительная таблица

| Вопрос | Named volume | Bind mount | tmpfs |
|---|---|---|---|
| Данные на диске? | Да | Да | Нет |
| Переживают `docker rm`? | Да | Да (это файлы хоста) | Нет |
| Переносимо между хостами? | Нет (нужен backup) | Нет | — |
| Нужен путь на хосте? | Нет | Да | Нет |
| Безопасен для секретов? | Нет | Нет | Да |
| Dev hot-reload? | Нет | Да | — |

---

## Типовые ошибки

| Ошибка | Причина | Решение |
|---|---|---|
| `down -v` и данные пропали | Volume удалён вместе с контейнером | Backup до `down -v` |
| Permission denied в bind mount | UID контейнера ≠ UID файла на хосте | `chown` или `user:` в compose |
| Bind mount пустой | Путь на хосте не существует | Docker создаёт пустую директорию |
| tmpfs данные исчезли | Контейнер был перезапущен | Ожидаемое поведение tmpfs |
| `docker volume prune` удалил нужный volume | Volume не был именован или не используется | Использовать named volumes, не делать prune без проверки |

---

## Вопросы для самопроверки

1. В чём разница между `docker compose down` и `docker compose down -v`?
2. Почему bind mount не подходит для данных PostgreSQL в production?
3. Когда tmpfs предпочтительнее named volume?
4. Что произойдёт с данными в named volume, если выполнить `docker volume prune`?
5. Как посмотреть, какие volumes подключены к работающему контейнеру?
6. Два контейнера пишут в один volume одновременно — какие проблемы могут возникнуть?

---

## Cleanup

```bash
./cleanup.sh
```
