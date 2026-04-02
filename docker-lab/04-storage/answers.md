# Ответы: 04-storage

## Результаты выполнения

- [ ] Часть 1: данные исчезли после `docker compose down` без volume
- [ ] Часть 2: данные пережили `docker compose down` + `up`
- [ ] Часть 2: backup создан и restore прошёл успешно
- [ ] Часть 3: hot-reload bind mount сработал без перезапуска контейнера
- [ ] Часть 4: данные в tmpfs исчезли после `restart`
- [ ] Часть 5: writer и reader работают через общий volume

## Ответы на вопросы

1. В чём разница между `docker compose down` и `docker compose down -v`?

2. Почему bind mount не подходит для данных PostgreSQL в production?

3. Когда tmpfs предпочтительнее named volume?

4. Что произойдёт с данными в named volume, если выполнить `docker volume prune`?

5. Как посмотреть, какие volumes подключены к работающему контейнеру?

6. Два контейнера пишут в один volume одновременно — какие проблемы могут возникнуть?

## Broken примеры — что наблюдал

- `compose-no-volume.yaml`:
- `compose-wrong-bind.yaml`:

## Что улучшить / чем опасно

-
