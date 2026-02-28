# 09. Registry и release flow

## Цель
Выстроить безопасный релиз контейнеров: теги, digest, push/pull, проверка политики.

## Теория
- `latest` как основной тег в CI/CD — anti-pattern.
- Релиз должен быть immutable: version tag + digest.
- Проверяйте, что деплой идет по digest, а не по плавающему тегу.
- Для подписи артефактов используйте современные инструменты (например, sigstore/cosign).

## Практика
1. Соберите образ для релиза:
```bash
docker build -t <registry>/<repo>/simple-web:1.0.0 ../02-images-dockerfile/lab
```
2. Проставьте дополнительные теги:
```bash
docker tag <registry>/<repo>/simple-web:1.0.0 <registry>/<repo>/simple-web:stable
```
3. Выполните push:
```bash
docker push <registry>/<repo>/simple-web:1.0.0
docker push <registry>/<repo>/simple-web:stable
```
4. Проверьте digest:
```bash
docker buildx imagetools inspect <registry>/<repo>/simple-web:1.0.0
```

## Проверка
- Релизный тег соответствует semver.
- Нет зависимости от `latest` в release-манифестах.
- Digest задокументирован.

## Типовые ошибки
- Перезапись старого тега без changelog.
- Отсутствие проверки digest перед деплоем.
- Push от локальной "грязной" сборки.

## Вопросы
1. Почему tag != identity образа?
2. В чем смысл immutable release process?
3. Где в пайплайне лучше проверять отсутствие `latest`?

## Дополнительные задания
- Добавьте подпись образа и проверку подписи.
- Добавьте policy check в CI.

## Cleanup
```bash
./cleanup.sh
```
