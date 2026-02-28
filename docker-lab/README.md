# Docker Lab

Практический курс по Docker от базовых команд до production-паттернов.

## Цель курса
- Дать пошаговый путь от `docker run` до безопасной и воспроизводимой сборки/эксплуатации контейнеров.
- Сформировать навыки диагностики проблем и подготовки контейнерных приложений к прод-использованию.

## Требования
- Docker Engine или Docker Desktop (актуальная версия).
- `docker compose` plugin.
- Bash-совместимая оболочка (Git Bash/WSL/Linux/macOS).
- Опционально для lint: `hadolint`, `yamllint`, `shellcheck`.

## Как проходить
1. Идите по модулям сверху вниз (`00` -> `12`).
2. В каждом модуле работайте по структуре `lab/`, `broken/`, `checks/`.
3. Ответьте на вопросы в `answers.md`.
4. После завершения модуля выполните `cleanup.sh`.

## Стандарт модуля
- `README.md` — теория, сценарий и критерии сдачи.
- `lab/` — рабочий стенд.
- `broken/` — преднамеренно сломанные сценарии.
- `checks/` — скрипты проверки результата.
- `answers.md` — self-check и разбор.
- `cleanup.sh` — откат окружения модуля.

## Критерии готовности
- Вы можете воспроизвести ключевые команды без подсказок.
- Каждая лабораторная имеет подтвержденный результат (`docker ps`, `docker logs`, `docker inspect`, проверки сети/данных).
- Для модулей `07+` есть обоснование по безопасности и релизной дисциплине (теги, digest, non-root).

## Порядок модулей
- [00-overview](./00-overview/README.md)
- [01-basics-cli](./01-basics-cli/README.md)
- [02-images-dockerfile](./02-images-dockerfile/README.md)
- [03-compose](./03-compose/README.md)
- [04-storage](./04-storage/README.md)
- [05-networking](./05-networking/README.md)
- [06-debug-troubleshooting](./06-debug-troubleshooting/README.md)
- [07-security](./07-security/README.md)
- [08-build-advanced](./08-build-advanced/README.md)
- [09-registry-release](./09-registry-release/README.md)
- [10-operations-observability](./10-operations-observability/README.md)
- [11-production-patterns](./11-production-patterns/README.md)
- [12-capstone-projects](./12-capstone-projects/README.md)

## Инструментирование
- `make lint` — lint Dockerfile/YAML/Shell.
- `make test` — базовая валидация compose-файлов.
- `make clean` — локальная очистка артефактов.

## Legacy-контент
Старые модули сохранены без потерь в [`legacy/`](./legacy/).
