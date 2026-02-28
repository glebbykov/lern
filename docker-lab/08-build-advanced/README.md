# 08. Advanced build: multi-stage, buildx, cache, targets

## Цель
Собирать production-ready образы: маленькие, воспроизводимые, мультиархитектурные.

## Теория
- Multi-stage разделяет builder/runtime.
- `buildx` нужен для `linux/amd64,linux/arm64` и удаленного кеша.
- Используйте pinned base image (digest) в релизном пайплайне.

## Практика
1. Локальная multi-stage сборка:
```bash
docker build -t dockerlab/go-api:dev ./lab
```
2. Запуск и проверка:
```bash
docker run --rm -p 8084:8084 dockerlab/go-api:dev
curl http://localhost:8084/healthz
```
3. Buildx (опционально):
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t <registry>/dockerlab/go-api:0.1.0 --push ./lab
```
4. Сравнение с `broken/Dockerfile.single`.

## Проверка
- Образ из `lab/Dockerfile` меньше и чище single-stage варианта.
- Приложение стартует и отвечает на health endpoint.

## Типовые ошибки
- Копирование всего workspace в builder.
- Отсутствие кеширования go modules.
- Неправильная target-платформа.

## Вопросы
1. Почему multi-stage уменьшает поверхность атаки?
2. Когда нужен `--target`?
3. Как использовать cache-from/cache-to в CI?

## Дополнительные задания
- Добавьте SBOM генерацию.
- Сравните cold start для двух образов.

## Cleanup
```bash
./cleanup.sh
```
