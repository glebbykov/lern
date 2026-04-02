# Ответы: 07-security

## Результаты выполнения

- [ ] Часть 1: контейнер работает от non-root пользователя
- [ ] Часть 2: `ReadonlyRootfs=true`, `/tmp` доступен через tmpfs
- [ ] Часть 3: `CapDrop=[ALL]` подтверждено через inspect
- [ ] Часть 4: `no-new-privileges:true` установлен
- [ ] Часть 5: секрет найден в `docker history` сломанного образа
- [ ] Часть 6: Trivy не нашёл HIGH/CRITICAL в hardened образе
- [ ] Часть 7: сравнение размеров и CVE между вариантами образа

## Ответы на вопросы

1. Какие capabilities Docker добавляет по умолчанию и почему это риск?

2. Почему `ARG SECRET=...` в Dockerfile — утечка?

3. Что даёт `no-new-privileges:true`? Как проверить?

4. Чем distroless лучше alpine для production и в чём его минус?

5. Как читать секрет из `/run/secrets/` в Python/Go/shell?

6. Trivy нашёл HIGH CVE в базовом образе, патча нет — что делать?

## Найденные проблемы в broken

- `broken/Dockerfile.secret`:

## Что улучшить

-
