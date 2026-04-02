# BuildKit secrets: безопасная передача секретов во время сборки
# Секрет доступен ТОЛЬКО во время RUN, не сохраняется в слоях образа

# syntax=docker/dockerfile:1.7
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

# Безопасное использование секрета при сборке
# Секрет монтируется как файл, доступен только во время этого RUN
# НЕ сохраняется в слоях образа (в отличие от ARG/ENV)
RUN --mount=type=secret,id=api_key \
    echo "Secret available at /run/secrets/api_key during build only" && \
    test -f /run/secrets/api_key && \
    echo "Build-time validation passed"

# Проверка что секрет НЕ остался в образе
# docker history покажет только RUN-команду, не содержимое секрета

USER nobody
CMD ["python", "app.py"]

# Сборка:
# echo "my-secret-key" > /tmp/api_key.txt
# docker build --secret id=api_key,src=/tmp/api_key.txt -t test-secret-mount .
# docker history test-secret-mount  ← секрет НЕ виден
