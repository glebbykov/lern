# Этап 3 — тот же Dockerfile, что и stage2. Всё сужение происходит
# на уровне docker-compose (read_only, cap_drop, no-new-privileges, лимиты).
FROM python:3.12-alpine

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

RUN addgroup -S appgroup && adduser -S -G appgroup -u 10001 appuser \
 && chown -R appuser:appgroup /app

USER appuser

EXPOSE 8083
CMD ["python", "app.py"]
