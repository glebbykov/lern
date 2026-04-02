"""Integration test: Redis в контейнере через Testcontainers."""

import redis
from testcontainers.redis import RedisContainer


def test_redis_set_get():
    """Запускает настоящий Redis, записывает и читает."""
    with RedisContainer("redis:7-alpine") as redis_container:
        # Получить параметры подключения (рандомный порт)
        host = redis_container.get_container_host_ip()
        port = redis_container.get_exposed_port(6379)
        print(f"Redis started at {host}:{port}")

        # Подключиться
        client = redis.Redis(host=host, port=int(port), decode_responses=True)

        # Записать
        client.set("greeting", "hello testcontainers")

        # Прочитать и проверить
        value = client.get("greeting")
        assert value == "hello testcontainers", f"expected 'hello testcontainers', got '{value}'"
        print(f"SET/GET ok: {value}")


def test_redis_ttl():
    """Проверяет реальный TTL в настоящем Redis (не мок)."""
    with RedisContainer("redis:7-alpine") as redis_container:
        host = redis_container.get_container_host_ip()
        port = redis_container.get_exposed_port(6379)

        client = redis.Redis(host=host, port=int(port), decode_responses=True)

        # SET с TTL
        client.setex("temp_key", 60, "temporary_value")

        # Проверить TTL
        ttl = client.ttl("temp_key")
        assert 0 < ttl <= 60, f"expected 0 < TTL <= 60, got {ttl}"
        print(f"TTL ok: {ttl}s")
