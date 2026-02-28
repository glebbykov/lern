# 12. Capstone проекты

## Цель
Собрать end-to-end проект, который доказывает практический уровень по Docker: build, runtime, networking, storage, security, release, observability.

## Формат сдачи
- Репозиторий проекта с `README`, `compose.yaml`, `Makefile` и скриптами проверки.
- Четкие acceptance criteria и демонстрация выполнения.
- Раздел "Known issues" и rollback-план.

## Треки
1. **Web + DB + Cache**
   - API + Postgres + Redis + миграции + healthchecks + monitoring.
2. **Event-driven**
   - Producer + Broker + Consumer + retry/DLQ + наблюдаемость.
3. **Security-first**
   - Non-root, read-only FS, cap-drop, scanning, release policy без `latest`.

## Acceptance criteria (обязательные)
- Все сервисы стартуют одной командой.
- Есть health endpoints и автоматические проверки.
- Есть стратегия хранения данных и backup/restore.
- Есть базовые security controls.
- Есть release flow с версионированием.

## Что оценивать
- Воспроизводимость (`make up/down/test`).
- Диагностируемость (логи, метрики, troubleshooting notes).
- Безопасность и минимизация рисков.
- Чистота Dockerfile/Compose конфигураций.

## Дополнительные задания
- Добавить multi-arch сборку.
- Добавить подпись образов.
- Подготовить mapping в Kubernetes primitives.

## Cleanup
```bash
./cleanup.sh
```
