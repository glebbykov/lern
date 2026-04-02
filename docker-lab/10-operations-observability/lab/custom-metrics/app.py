"""Flask app с Prometheus-метриками.

Экспортирует:
- http_requests_total (Counter) — общее количество запросов
- http_request_duration_seconds (Histogram) — время обработки
- app_active_connections (Gauge) — текущие соединения
"""

import time
import random
from flask import Flask, Response
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# Определение метрик
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['endpoint'],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]
)

ACTIVE_CONNECTIONS = Gauge(
    'app_active_connections',
    'Number of active connections'
)


@app.get('/')
def root():
    ACTIVE_CONNECTIONS.inc()
    start = time.time()

    # Имитация переменного времени обработки
    time.sleep(random.uniform(0.01, 0.1))
    response = {'message': 'hello', 'timestamp': time.time()}

    duration = time.time() - start
    REQUEST_COUNT.labels(method='GET', endpoint='/', status='200').inc()
    REQUEST_DURATION.labels(endpoint='/').observe(duration)
    ACTIVE_CONNECTIONS.dec()

    return response


@app.get('/healthz')
def healthz():
    REQUEST_COUNT.labels(method='GET', endpoint='/healthz', status='200').inc()
    return {'status': 'ok'}


@app.get('/metrics')
def metrics():
    """Prometheus /metrics endpoint."""
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
