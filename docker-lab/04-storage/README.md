# 04. Storage: volumes, bind mounts, tmpfs

## Цель
Освоить персистентность данных и безопасные backup/restore сценарии.

## Теория
- `volume` — управляется Docker, лучший дефолт для данных сервисов.
- `bind mount` — доступ к директории хоста, полезно для dev.
- `tmpfs` — данные в памяти, исчезают после остановки контейнера.

## Практика
1. Поднимите Postgres с volume:
```bash
docker compose -f lab/compose.yaml up -d
```
2. Создайте тестовые данные:
```bash
docker compose -f lab/compose.yaml exec db psql -U appuser -d appdb -c "INSERT INTO notes(text) VALUES ('hello');"
```
3. Сделайте backup:
```bash
./lab/scripts/backup.sh
```
4. Очистите и восстановите данные:
```bash
./lab/scripts/restore.sh
```

## Проверка
- Данные переживают `docker compose down`/`up` без `-v`.
- Backup-файл создается и пригоден для восстановления.

## Типовые ошибки
- Перепутан путь volume внутри контейнера.
- Восстановление выполняется в не ту БД.
- `down -v` выполнен до backup.

## Вопросы
1. Почему volume предпочтительнее bind mount для БД?
2. Чем опасен backup без проверки restore?
3. Когда имеет смысл tmpfs?

## Дополнительные задания
- Добавьте ежедневный cron-backup.
- Проверьте права доступа на backup-артефакты.

## Cleanup
```bash
./cleanup.sh
```
