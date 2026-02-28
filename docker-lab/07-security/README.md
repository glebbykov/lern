# 07. Security и hardening

## Цель
Снизить риск на уровне образа и рантайма: non-root, read-only FS, минимальные capabilities, отсутствие секретов в слоях.

## Теория
- Минимальный базовый образ и минимальный runtime-контекст.
- `USER` != root по умолчанию.
- `read_only`, `tmpfs`, `no-new-privileges`, `cap_drop`.
- Секреты не должны попадать в `Dockerfile`, git, слои и логи.

## Практика
1. Соберите secure-образ:
```bash
docker build -t dockerlab/secure-app:dev ./lab
```
2. Поднимите стенд:
```bash
docker compose -f lab/compose.yaml up -d --build
```
3. Проверьте hardening:
```bash
docker inspect security-app --format '{{.Config.User}}'
docker inspect security-app --format '{{.HostConfig.ReadonlyRootfs}}'
```
4. Сравните с `broken/Dockerfile.secret`.

## Проверка
- Контейнер работает от non-root.
- Корневая ФС read-only.
- `cap_drop: [ALL]` применен.

## Типовые ошибки
- Запуск от root "пока так проще".
- Токены в `ENV`/`ARG`.
- Неполный hardening: забыли tmpfs для временных файлов.

## Вопросы
1. Какие возможности теряет контейнер при `cap_drop: ALL`?
2. Чем секрет в env лучше/хуже секрета в файле?
3. Что дает `no-new-privileges`?

## Дополнительные задания
- Прогоните образ через Trivy.
- Добавьте policy-check, запрещающий `latest` и root.

## Cleanup
```bash
./cleanup.sh
```
