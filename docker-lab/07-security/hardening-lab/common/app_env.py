"""
Anti-pattern / early-stage variant.

- Читает секрет из переменной окружения SECRET (плохо).
- Пишет логи в /app/requests.log, то есть прямо в rootfs контейнера.
"""
import os
from datetime import datetime
from pathlib import Path

from flask import Flask, jsonify, request

SECRET = os.environ.get("SECRET", "unset")
LOG_PATH = Path(os.environ.get("LOG_PATH", "/app/requests.log"))

app = Flask(__name__)


def mask(value: str) -> str:
    if not value or value == "unset":
        return "unset"
    if len(value) <= 4:
        return "*" * len(value)
    return value[:2] + "*" * (len(value) - 4) + value[-2:]


@app.get("/healthz")
def healthz():
    return jsonify(status="ok", source="env")


@app.get("/secret")
def secret():
    return jsonify(source="env", masked=mask(SECRET), length=len(SECRET))


@app.post("/log")
def log_line():
    payload = request.get_json(silent=True) or {}
    line = f"{datetime.utcnow().isoformat()}Z {payload.get('msg', 'hello')}\n"
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a") as f:
        f.write(line)
    return jsonify(written_to=str(LOG_PATH), line=line.strip())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8083)
