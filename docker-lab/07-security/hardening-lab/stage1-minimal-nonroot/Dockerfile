# Этап 1 — правила 1 и 6.
#   * Правило 1: минимальный образ (python:3.12-alpine вместо ubuntu).
#   * Правило 6: явный non-root пользователь через USER.
# Секрет всё ещё через ENV — его уберём на этапе 2.
FROM python:3.12-alpine

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SECRET=supersecret_do_not_leak

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

# Не-привилегированный пользователь: создаём и ПЕРЕКЛЮЧАЕМСЯ.
RUN addgroup -S appgroup && adduser -S -G appgroup -u 10001 appuser \
 && chown -R appuser:appgroup /app

USER appuser

EXPOSE 8083
CMD ["python", "app.py"]
