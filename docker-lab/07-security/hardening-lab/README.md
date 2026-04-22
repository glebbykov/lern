# Docker Hardening Lab — от anti-pattern до hardened

Лаборатория проходится строго по порядку. Каждая папка — это
отдельный этап, показывающий одно правило hardening в действии.

```
stage0-antipattern       — как делать НЕ надо (отправная точка)
stage1-minimal-nonroot   — правила 1 и 6: минимальная база + non-root
stage2-secrets           — правило 5: секреты через Compose secrets
stage3-runtime-locked    — правила 2, 3, 4: read-only, caps, no-new-privileges, лимиты
stage4-breakin-checks    — активная проверка, что ограничения работают
stage5-scan              — правило 7: аудит через Trivy
```

## Требования

- Docker 24+ и docker compose v2
- `curl` для проверки HTTP
- Trivy (см. `stage5-scan/README.md` — ставится скриптом)

## Быстрый прогон

```bash
# Каждый этап запускается из своей папки:
cd stage0-antipattern && ./run.sh
cd ../stage1-minimal-nonroot && ./run.sh
cd ../stage2-secrets && ./run.sh
cd ../stage3-runtime-locked && ./run.sh
cd ../stage4-breakin-checks && ./run.sh    # проверки взлома
cd ../stage5-scan && ./run.sh              # Trivy
```

Или целиком одним скриптом:

```bash
./run-all.sh
```

## Приложение

Простой Flask-сервис на порту 8083 (чтобы не конфликтовать с уже
занятыми 8080/8000):

- `GET /healthz` — живость
- `GET /secret` — показывает маскированный секрет, подтверждая
  путь чтения (ENV в stage0/1, `/run/secrets` в stage2+)
- `POST /log` — пишет лог-строку в директорию, которая на разных
  этапах либо свободно пишется (stage0), либо доступна только через
  tmpfs (stage3). Это нужно для наглядной демонстрации `read_only`.
