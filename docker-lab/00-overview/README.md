# 00. Overview и установка

## Цель
Подготовить рабочую среду и зафиксировать базовую ментальную модель Docker: `image`, `container`, `layer`, `registry`, `engine`, `compose`.

## Что важно в 2026
- Используйте `docker compose` (plugin v2), а не legacy `docker-compose`.
- Для production-release ориентируйтесь на digest и подпись артефактов, а не на mutable-теги.
- Проверяйте архитектуру (`amd64`/`arm64`) перед сборкой и запуском.

## Prereq
- Docker Engine 26+ или Docker Desktop (актуальная стабильная версия).
- Доступ к интернету для pull образов.
- Права на запуск Docker без `sudo` (Linux) или через Docker Desktop (Windows/macOS).

## Практика
1. Проверка версии и окружения:
```bash
docker version
docker info
docker compose version
```
2. Первый контейнер:
```bash
docker run --rm hello-world
```
3. Проверка архитектуры и драйверов:
```bash
docker info --format '{{json .}}'
```
4. Фиксация результатов в `answers.md`.

## Проверка
- Команды выполняются без ошибок.
- `hello-world` успешно запускается.
- Понимаете разницу между `image` и `container`.

## Типовые ошибки
- Docker daemon не запущен.
- WSL2 backend не включен (Windows).
- Недостаточно прав пользователя на Linux (`docker` group).

## Вопросы
1. Что происходит внутри при `docker run hello-world`?
2. Чем отличается слой образа от writable слоя контейнера?
3. Когда стоит использовать `--platform`?

## Дополнительные задания
- Сравните вывод `docker info` на двух разных ОС.
- Найдите и объясните storage driver в своем окружении.

## Файлы модуля
- `lab/check-env.sh` / `lab/check-env.ps1` — быстрые smoke-check скрипты.
- `broken/common-issues.md` — типовые проблемы и диагностика.
- `checks/verify.sh` — минимальная проверка готовности.

## Cleanup
```bash
./cleanup.sh
```
