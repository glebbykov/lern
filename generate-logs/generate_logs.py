#!/usr/bin/env python3
"""
generate_logs.py — генератор реалистичных лог-файлов.

Использование:
  python generate_logs.py -n 1000 -o app.log
  python generate_logs.py -n 500 --format nginx -o access.log
  python generate_logs.py -n 200 --format json
  python generate_logs.py --from-date 2024-01-01 --to-date 2024-12-31 -n 300
  python generate_logs.py -n 100 --seed 42            # воспроизводимый результат
  python generate_logs.py -n 50 --config myconfig.json
"""

import argparse
import json
import random
import sys
from datetime import datetime, timedelta


# ─── данные для генерации ─────────────────────────────────────────────────────

HOSTNAMES = [
    "web-01", "web-02", "api-server", "db-primary", "cache-01",
    "worker-03", "auth-service", "gateway", "scheduler", "monitor-01",
]

SERVICES = [
    "nginx", "sshd", "systemd", "kernel", "cron", "dockerd",
    "postgres", "redis", "prometheus", "node-exporter",
]

USERNAMES = [
    "admin", "deploy", "root", "ci-runner", "backup", "monitor",
    "alice", "bob", "carol", "dave",
]

MESSAGES_BY_LEVEL = {
    "INFO": [
        "Service started successfully",
        "Configuration reloaded",
        "Health check passed",
        "Backup completed in 12.3s",
        "Connection pool initialized (size=10)",
        "Cache warmed up: 4823 entries",
        "Scheduled task executed",
        "User session created",
        "Metrics exported",
        "Node joined the cluster",
    ],
    "WARNING": [
        "Disk usage at 82% on /var",
        "Response time exceeded 500ms threshold",
        "Retry attempt 2/3 for upstream",
        "Certificate expires in 14 days",
        "Memory usage above 75%",
        "Connection pool exhausted, waiting",
        "Slow query detected (1243ms)",
        "Rate limit approaching for client",
        "Config file changed on disk",
        "Unexpected restart detected",
    ],
    "ERROR": [
        "Failed to connect to database: timeout",
        "Permission denied: /etc/secrets/token",
        "HTTP 502 Bad Gateway from upstream",
        "Out of disk space on /tmp",
        "TLS handshake failed",
        "Authentication failed for user root",
        "Process exited with code 1",
        "Cannot bind to port 8080: address in use",
        "Backup job failed: destination unreachable",
        "Invalid configuration value: max_conn=-1",
    ],
    "DEBUG": [
        "Entering handler: POST /api/v1/users",
        "Cache miss for key session:abc123",
        "SQL: SELECT * FROM events WHERE id=$1 [42ms]",
        "Goroutine pool: 12 active, 4 idle",
        "Parsed config: timeout=30s retries=3",
        "TCP keepalive sent to 10.0.1.5",
        "Decoded JWT payload: sub=user42 exp=+3600",
        "Lock acquired: mutex:queue:processing",
        "Webhook payload size: 4.2 KB",
        "Feature flag 'new-ui' is OFF",
    ],
    "CRITICAL": [
        "etcd cluster unreachable — control plane down",
        "Database replication lag: 92 seconds",
        "OOM killer invoked: pid 3821 killed",
        "RAID degraded: disk /dev/sdb failed",
        "Security policy violation: root login via SSH",
        "All replicas unhealthy — circuit breaker open",
    ],
}

# уровни и их вероятности
LOG_LEVELS = ["INFO", "WARNING", "ERROR", "DEBUG", "CRITICAL"]
LOG_WEIGHTS = [0.55, 0.20, 0.15, 0.08, 0.02]

# HTTP методы / коды для nginx-формата
HTTP_METHODS = ["GET", "POST", "PUT", "DELETE", "PATCH"]
HTTP_PATHS = [
    "/", "/api/v1/users", "/api/v1/health", "/api/v1/metrics",
    "/login", "/logout", "/admin", "/static/app.js", "/favicon.ico",
    "/api/v1/orders", "/api/v1/products", "/api/v2/search",
]
HTTP_STATUS_WEIGHTS = {
    200: 0.60, 201: 0.08, 204: 0.04,
    301: 0.03, 304: 0.05,
    400: 0.05, 401: 0.04, 403: 0.03, 404: 0.05,
    500: 0.02, 502: 0.01,
}
USER_AGENTS = [
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
    'curl/8.5.0',
    'python-httpx/0.26.0',
    'Go-http-client/2.0',
    'Prometheus/2.49.0',
    'kube-probe/1.29',
]


# ─── форматы вывода ───────────────────────────────────────────────────────────

def fmt_syslog(ts: datetime, host: str, service: str, level: str, msg: str) -> str:
    """
    Стандартный syslog-формат:
    2024-03-15T14:32:01 web-01 nginx[3821]: [INFO] Health check passed
    """
    return f"{ts.strftime('%Y-%m-%dT%H:%M:%S')} {host} {service}[{random.randint(1000, 9999)}]: [{level}] {msg}"


def fmt_json(ts: datetime, host: str, service: str, level: str, msg: str) -> str:
    """JSON, один объект на строку (NDJSON)."""
    record = {
        "timestamp": ts.isoformat(),
        "host": host,
        "service": service,
        "level": level,
        "message": msg,
    }
    return json.dumps(record, ensure_ascii=False)


def fmt_nginx(ts: datetime, ip: str, method: str, path: str,
              status: int, size: int, agent: str) -> str:
    """
    Nginx combined access log format.
    """
    ts_str = ts.strftime('%d/%b/%Y:%H:%M:%S +0000')
    return f'{ip} - - [{ts_str}] "{method} {path} HTTP/1.1" {status} {size} "-" "{agent}"'


# ─── генераторы ───────────────────────────────────────────────────────────────

def random_ip(prefix: str = "10.0") -> str:
    return f"{prefix}.{random.randint(1, 254)}.{random.randint(1, 254)}"


def random_timestamp(start: datetime, end: datetime) -> datetime:
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))


def generate_syslog_entry(start: datetime, end: datetime) -> str:
    ts = random_timestamp(start, end)
    host = random.choice(HOSTNAMES)
    service = random.choice(SERVICES)
    level = random.choices(LOG_LEVELS, weights=LOG_WEIGHTS, k=1)[0]
    msg = random.choice(MESSAGES_BY_LEVEL[level])
    return fmt_syslog(ts, host, service, level, msg)


def generate_json_entry(start: datetime, end: datetime) -> str:
    ts = random_timestamp(start, end)
    host = random.choice(HOSTNAMES)
    service = random.choice(SERVICES)
    level = random.choices(LOG_LEVELS, weights=LOG_WEIGHTS, k=1)[0]
    msg = random.choice(MESSAGES_BY_LEVEL[level])
    return fmt_json(ts, host, service, level, msg)


def generate_nginx_entry(start: datetime, end: datetime) -> str:
    ts = random_timestamp(start, end)
    ip = random_ip()
    method = random.choice(HTTP_METHODS)
    path = random.choice(HTTP_PATHS)
    statuses = list(HTTP_STATUS_WEIGHTS.keys())
    weights = list(HTTP_STATUS_WEIGHTS.values())
    status = random.choices(statuses, weights=weights, k=1)[0]
    size = random.randint(200, 25000)
    agent = random.choice(USER_AGENTS)
    return fmt_nginx(ts, ip, method, path, status, size, agent)


GENERATORS = {
    "syslog": generate_syslog_entry,
    "json":   generate_json_entry,
    "nginx":  generate_nginx_entry,
}


# ─── CLI ──────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Генератор реалистичных лог-файлов",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры:
  %(prog)s -n 1000 -o app.log
  %(prog)s -n 500 --format nginx -o access.log
  %(prog)s -n 200 --format json --from-date 2024-01-01 --to-date 2024-06-30
  %(prog)s -n 100 --seed 42
  %(prog)s -n 50 --config myconfig.json
""",
    )
    parser.add_argument("-n", "--count",      type=int, default=100,
                        help="количество записей (по умолчанию: 100)")
    parser.add_argument("-o", "--output",     default=None,
                        help="выходной файл (по умолчанию: stdout)")
    parser.add_argument("-f", "--format",     choices=["syslog", "json", "nginx"],
                        default="syslog",
                        help="формат логов (по умолчанию: syslog)")
    parser.add_argument("--from-date",        default=None,
                        metavar="YYYY-MM-DD",
                        help="начало диапазона дат (по умолчанию: 30 дней назад)")
    parser.add_argument("--to-date",          default=None,
                        metavar="YYYY-MM-DD",
                        help="конец диапазона дат (по умолчанию: сейчас)")
    parser.add_argument("--seed",             type=int, default=None,
                        help="зафиксировать random seed для воспроизводимости")
    parser.add_argument("--config",           default=None,
                        metavar="FILE",
                        help="JSON конфиг-файл (переопределяет дефолты)")
    parser.add_argument("-v", "--verbose",    action="store_true",
                        help="вывести прогресс в stderr")
    return parser.parse_args()


def load_config(path: str) -> dict:
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Ошибка чтения конфига {path}: {e}", file=sys.stderr)
        sys.exit(1)


def parse_date(s: str, name: str) -> datetime:
    try:
        return datetime.strptime(s, "%Y-%m-%d")
    except ValueError:
        print(f"Неверный формат даты для {name}: '{s}' (ожидается YYYY-MM-DD)", file=sys.stderr)
        sys.exit(1)


# ─── точка входа ─────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()

    # конфиг-файл (опционально)
    if args.config:
        cfg = load_config(args.config)
        args.count  = cfg.get("num_logs", args.count)
        args.format = cfg.get("format", args.format)
        args.output = cfg.get("output_file", args.output)

    # seed
    if args.seed is not None:
        random.seed(args.seed)

    # диапазон дат
    now = datetime.now().replace(microsecond=0)
    date_from = parse_date(args.from_date, "--from-date") if args.from_date else now - timedelta(days=30)
    date_to   = parse_date(args.to_date,   "--to-date")   if args.to_date   else now

    if date_from >= date_to:
        print("Ошибка: --from-date должна быть раньше --to-date", file=sys.stderr)
        sys.exit(1)

    generator = GENERATORS[args.format]

    # генерация
    lines = []
    for i in range(args.count):
        lines.append(generator(date_from, date_to))
        if args.verbose and (i + 1) % 1000 == 0:
            print(f"  {i + 1}/{args.count}...", file=sys.stderr)

    # вывод
    output = "\n".join(lines) + "\n"

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output)
        if args.verbose:
            print(f"Записано {args.count} строк в '{args.output}' (формат: {args.format})", file=sys.stderr)
        else:
            print(f"Записано {args.count} строк в '{args.output}' (формат: {args.format})")
    else:
        sys.stdout.write(output)


if __name__ == "__main__":
    main()
