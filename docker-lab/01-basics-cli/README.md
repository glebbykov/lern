# 01. CLI база и жизненный цикл контейнера

## Цель
Уверенно работать с контейнером на всем lifecycle: запуск, диагностика, остановка, удаление, рестарт-политики.

## Теория
- Ключевые команды: `run`, `ps`, `logs`, `exec`, `inspect`, `top`, `stats`, `stop`, `rm`.
- Контейнер жив, пока жив PID 1 внутри контейнера.
- `--restart` полезен для демонов, но не заменяет оркестратор.

## Практика
1. Запустите nginx:
```bash
docker run -d --name cli-nginx -p 8080:80 --restart unless-stopped nginx:1.27-alpine
```
2. Проверьте состояние:
```bash
docker ps
docker logs cli-nginx --tail 20
docker inspect cli-nginx --format '{{.State.Status}}'
```
3. Диагностика внутри контейнера:
```bash
docker exec -it cli-nginx sh
```
4. Проверьте процессы и ресурсы:
```bash
docker top cli-nginx
docker stats cli-nginx --no-stream
```
5. Остановите и удалите контейнер:
```bash
docker stop cli-nginx
docker rm cli-nginx
```

## Проверка
- Контейнер доступен на `http://localhost:8080`.
- Умеете получить PID процесса и состояние контейнера через `inspect`.
- Понимаете, как работает `--restart`.

## Типовые ошибки
- Порт 8080 уже занят.
- Перепутан `container name` и `image name`.
- Запуск интерактивной команды без `-it`.

## Вопросы
1. Почему важно, какой процесс является PID 1?
2. Чем `docker stop` отличается от `docker kill`?
3. Когда `--restart always` может быть вреден?

## Дополнительные задания
- Сымитируйте падение процесса и отследите поведение restart policy.
- Найдите PID контейнера на хосте.

## Файлы модуля
- `lab/run-nginx.sh` — быстрый сценарий запуска.
- `broken/crashloop.sh` — пример контейнера, который постоянно падает.
- `checks/verify.sh` — автоматическая проверка базовых команд.

## Cleanup
```bash
./cleanup.sh
```
