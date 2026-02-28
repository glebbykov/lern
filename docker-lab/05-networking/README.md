# 05. Networking: bridge, host, DNS, публикация портов

## Цель
Понять, как контейнеры общаются между собой, как работает service discovery и чем `EXPOSE` отличается от publish (`-p`).

## Теория
- Docker DNS резолвит имена сервисов в пределах одной сети.
- `EXPOSE` — декларация порта внутри образа, не публикует порт на хост.
- Публикация `-p 8080:80` делает сервис доступным с хоста.

## Практика
1. Запустите стенд:
```bash
docker compose -f lab/compose.yaml up -d
```
2. Проверьте доступ с хоста:
```bash
curl http://localhost:8082
```
3. Проверьте DNS внутри контейнера:
```bash
docker compose -f lab/compose.yaml exec toolbox nslookup api
docker compose -f lab/compose.yaml exec toolbox nslookup db
```
4. Изучите сети:
```bash
docker network ls
docker network inspect 05-networking_frontend
```

## Проверка
- `edge` доступен с хоста.
- `toolbox` резолвит `api` и `db`.
- Понимаете, почему `db` не должен иметь опубликованный порт наружу по умолчанию.

## Типовые ошибки
- Контейнеры в разных сетях и не видят друг друга.
- Порт опубликован не на том интерфейсе.
- Неправильный network alias.

## Вопросы
1. Когда publish порта к хосту не нужен?
2. Почему сервис может резолвиться, но быть недоступным?
3. Какие риски у `network_mode: host`?

## Дополнительные задания
- Подключите `toolbox` только к одной сети и проверьте, что ломается.
- Добавьте ограничение `internal: true` для backend сети.

## Cleanup
```bash
./cleanup.sh
```
