# 06. Debug и troubleshooting

## Цель
Системно диагностировать runtime-проблемы: crashloop, конфликт портов, DNS-проблемы, нехватку ресурсов.

## Подход к диагностике
1. Зафиксировать симптом.
2. Подтвердить факт (логи, события, inspect).
3. Выдвинуть гипотезу.
4. Проверить гипотезу минимальным изменением.
5. Зафиксировать постоянный fix.

## Инструменты
- `docker logs`, `docker inspect`, `docker events`, `docker stats`
- `docker compose ps`, `docker compose logs`
- Коды выхода (`137`, `143`, `1` и т.д.)

## Практика
1. CrashLoop сценарий:
```bash
docker compose -f broken/compose-crashloop.yaml up -d
docker compose -f broken/compose-crashloop.yaml logs --tail 50
docker inspect dbg-crash --format '{{.State.ExitCode}}'
```
2. Конфликт портов:
```bash
docker compose -f broken/compose-port-conflict.yaml up -d
```
3. DNS-проблема:
```bash
docker compose -f broken/compose-dns.yaml up -d
docker compose -f broken/compose-dns.yaml exec -T client nslookup api
```

## Проверка
- Для каждого сценария указан root cause и конкретный fix.
- Есть доказательство до/после (команды и вывод).

## Типовые ошибки
- Лечение симптома вместо причины.
- Отсутствие репродукции проблемы.
- Проверка "на глаз" без метрик/логов.

## Вопросы
1. Что означает exit code `137`?
2. Чем отличается `restart: always` от исправления реальной причины падения?
3. Какие данные из `inspect` обязательны при расследовании?

## Дополнительные задания
- Добавьте сценарий с `read-only filesystem` ошибкой записи.
- Добавьте сценарий с переполнением логов.

## Cleanup
```bash
./cleanup.sh
```
