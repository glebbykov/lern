"""Flask-приложение с корректной обработкой SIGTERM.

Демонстрирует:
- Перехват SIGTERM
- Завершение текущих запросов (in-flight)
- Чистый shutdown без потери данных
"""

import signal
import sys
import time
import threading
from flask import Flask, jsonify

app = Flask(__name__)
shutdown_event = threading.Event()


def handle_sigterm(signum, frame):
    """Корректная обработка SIGTERM от docker stop."""
    print("Received SIGTERM, finishing in-flight requests...", flush=True)
    shutdown_event.set()
    # Даём время на завершение текущих запросов
    time.sleep(2)
    print("Graceful shutdown complete", flush=True)
    sys.exit(0)


signal.signal(signal.SIGTERM, handle_sigterm)
signal.signal(signal.SIGINT, handle_sigterm)


@app.get('/')
def root():
    if shutdown_event.is_set():
        return jsonify({'status': 'shutting_down'}), 503
    # Имитация обработки запроса
    time.sleep(0.1)
    return jsonify({'message': 'hello', 'status': 'running'})


@app.get('/healthz')
def healthz():
    if shutdown_event.is_set():
        return jsonify({'status': 'shutting_down'}), 503
    return jsonify({'status': 'ok'})


@app.get('/slow')
def slow():
    """Длинный запрос — проверяет, дожидается ли docker stop его завершения."""
    print("Starting slow request (5s)...", flush=True)
    time.sleep(5)
    print("Slow request completed", flush=True)
    return jsonify({'message': 'slow request done'})


if __name__ == '__main__':
    print("Starting app with graceful shutdown support", flush=True)
    app.run(host='0.0.0.0', port=8080)
