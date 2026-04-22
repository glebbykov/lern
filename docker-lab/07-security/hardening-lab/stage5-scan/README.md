# Этап 5 — аудит и сканирование (правило 7)

Trivy сравнивает два образа:

- `hardening-lab/stage0:latest` (ubuntu:latest + python3) — «до».
- `hardening-lab/stage3:latest` (python:3.12-alpine)      — «после».

Отчёты фильтруются по `HIGH,CRITICAL` и сохраняются в `reports/`.

Если Trivy не установлен на хосте, скрипт запустит его внутри
контейнера `aquasec/trivy`.

```bash
./run.sh
```

Типичный результат: у ubuntu-образа десятки HIGH/CRITICAL (apt,
coreutils, и т.п.), у alpine-образа — единицы или 0.
