# Capstone: Security-first

## ТЗ
Соберите сервис с приоритетом на безопасность runtime и release.

## Acceptance criteria
- Non-root, read-only rootfs, cap-drop.
- Secret handling без утечек в слои.
- Сканирование образа и policy check.
- Теги релизов immutable, без `latest`.

## Типовые баги для тренировки
- Секрет в Dockerfile.
- Runtime требует root-права.
- CI пропускает критические CVE.
