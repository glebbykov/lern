import random
import string
import json
from collections import defaultdict
from datetime import datetime

# Чтение конфигурации из файла
with open("config.json", "r") as config_file:
    config = json.load(config_file)

ENABLE_LOGGING = config["enable_logging"]
NUM_LOGS = config["num_logs"]
IP_GROUPS = config["ip_groups"]

# Разбор IP-групп в префиксы
def generate_ip_from_prefix(prefix):
    base_ip, subnet = prefix.split("/")
    subnet = int(subnet)
    base_ip_parts = base_ip.split(".")
    ip_parts = [
        int(part) if i < subnet // 8 else random.randint(0, 255)
        for i, part in enumerate(base_ip_parts)
    ]
    return ".".join(map(str, ip_parts))

def select_ip_address(ip_groups):
    """Возвращает случайный IP-адрес на основе указанных групп и частот."""
    prefixes, probabilities = zip(*ip_groups.items())
    selected_prefix = random.choices(prefixes, probabilities, k=1)[0]
    return generate_ip_from_prefix(selected_prefix)

# Типы логов
LOG_TYPES = [
    "INFO",
    "ERROR",
    "WARNING",
    "DEBUG",
    "CRITICAL",
    "NOTICE",
    "ALERT",
    "FATAL",
    "TRACE",
    "VERBOSE",
    "SYSLOG",
    "MAILLOG",
    "EVENTLOG",
    "SECURITY",
    "AUTH",
    "ACCESS",
    "AUDIT",
    "CONNECTION",
    "TRANSACTION",
    "APPLICATION"
]

# Шаблоны записей логов
LOG_PATTERNS = {
    "INFO": "Info message: {msg} - {user}",
    "ERROR": "Error occurred: {msg} - {user}",
    "WARNING": "Warning: {msg} - {user}",
    "DEBUG": "Debug info: {msg} - {user}",
    "CRITICAL": "Critical issue: {msg} - {user}",
    "NOTICE": "Notice: {msg} - {user}",
    "ALERT": "Alert! {msg} - {user}",
    "FATAL": "Fatal error: {msg} - {user}",
    "TRACE": "Trace info: {msg} - {user}",
    "VERBOSE": "Verbose output: {msg} - {user}",
    "SYSLOG": "Syslog entry: {msg} - {user}",
    "MAILLOG": "Maillog entry: {msg} - {user}",
    "EVENTLOG": "Event logged: {msg} - {user}",
    "SECURITY": "Security alert: {msg} - {user}",
    "AUTH": "Auth issue: {msg} - {user}",
    "ACCESS": "Access granted to {user}",
    "AUDIT": "Audit log: {msg} - {user}",
    "CONNECTION": "Connection from {ip} - {user}",
    "TRANSACTION": "Transaction complete: {msg} - {user}",
    "APPLICATION": "Application log: {msg} - {user}"
}

# Случайный текст для логов
MESSAGES = [
    "System started",
    "User login failed",
    "Connection established",
    "File not found",
    "Configuration updated",
    "Disk space low",
    "Service restarted",
    "Password changed",
    "Permission denied",
    "User authenticated",
    "Resource temporarily unavailable",
    "Network timeout",
    "Database query executed",
    "File uploaded successfully",
    "User profile updated",
    "Invalid credentials",
    "Remote session started",
    "Policy violation detected",
    "Backup completed",
    "Data encryption enabled"
]

# Генератор случайных логов
def generate_log_entry(ip_groups, log_types, log_patterns, messages):
    log_type = random.choice(log_types)
    pattern = log_patterns[log_type]
    user = "".join(random.choices(string.ascii_letters, k=8))
    ip = select_ip_address(ip_groups)
    msg = random.choice(messages)
    
    timestamp = datetime.fromtimestamp(random.randint(1610000000, 1700000000)).strftime('%Y-%m-%d %H:%M:%S')
    log_message = pattern.format(user=user, ip=ip, msg=msg)
    
    return f"{timestamp} {log_type} {ip} - {log_message}"

# Генерация логов с заданным количеством записей
def generate_logs(num_logs, ip_groups, log_types, log_patterns, messages):
    logs = [generate_log_entry(ip_groups, log_types, log_patterns, messages) for _ in range(num_logs)]
    return logs

# Пример генерации логов и сохранения их в файл
if __name__ == "__main__":
    if ENABLE_LOGGING:
        logs = generate_logs(NUM_LOGS, IP_GROUPS, LOG_TYPES, LOG_PATTERNS, MESSAGES)
        
        with open("generated_logs.log", "w") as f:
            for log in logs:
                f.write(log + "\n")
        
        print(f"Generated {NUM_LOGS} log entries in 'generated_logs.log'")
    else:
        print("Logging is disabled by configuration")
