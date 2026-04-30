FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 80

# Один воркер достаточно для Phase 1 (smoke + metrics).
# python:3.12-slim вместо alpine — prebuilt wheels для asyncpg/aiokafka/motor.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--log-level", "info"]
