# Ответы: 06-debug-troubleshooting

## Результаты выполнения

- [ ] Сценарий 1: crashloop — найден root cause, указан exit code
- [ ] Сценарий 2: конфликт портов — найден процесс, занимающий порт
- [ ] Сценарий 3: DNS fail — объяснена причина изоляции сетей
- [ ] Сценарий 4: OOM kill — подтверждён через OOMKilled=true
- [ ] Сценарий 5: healthcheck fail — найден неверный путь проверки
- [ ] Сценарий 6: read-only fs — найден флаг ReadonlyRootfs
- [ ] Сценарий 7: missing env — найдена отсутствующая переменная
- [ ] Сценарий 8: wrong image — получена ошибка manifest not found
- [ ] Сценарий 9: volume perm — найдено несоответствие UID и прав
- [ ] Сценарий 10: EXPOSE vs ports — разница понята и проверена

## Root cause и fix по каждому сценарию

**Сценарий 1 — CrashLoop:**
- Root cause:
- Fix:

**Сценарий 2 — Port conflict:**
- Root cause:
- Fix:

**Сценарий 3 — DNS:**
- Root cause:
- Fix:

**Сценарий 4 — OOM:**
- Root cause:
- Fix:

**Сценарий 5 — Healthcheck:**
- Root cause:
- Fix:

**Сценарий 6 — Read-only:**
- Root cause:
- Fix:

**Сценарий 7 — Missing env:**
- Root cause:
- Fix:

**Сценарий 8 — Wrong image:**
- Root cause:
- Fix:

**Сценарий 9 — Volume perm:**
- Root cause:
- Fix:

## Ответы на вопросы

1. Что означает exit code `137` и как отличить OOM kill от `docker kill`?

2. Чем опасен `restart: always` без исправления реальной причины падения?

3. Какой командой узнать, был ли контейнер убит OOM killer'ом?

4. Почему `EXPOSE` не делает сервис доступным с хоста?

5. Контейнер `Up`, healthcheck `unhealthy` — зависимые сервисы стартуют?

6. Как войти в контейнер без `sh`/`bash` (distroless образ)?

7. Что показывает `docker events` и чем оно полезнее `docker logs`?

8. Как узнать реальное потребление памяти перед выставлением лимита?

## Что улучшить / чем опасно

-
