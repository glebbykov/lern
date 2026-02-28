# Troubleshooting Checklist

1. Симптом и время проблемы.
2. Что изменилось перед инцидентом.
3. `docker compose ps` / `docker ps -a`.
4. `docker logs --tail 200`.
5. `docker inspect` (state, health, mounts, network).
6. Проверка ресурсов (`stats`, disk, memory).
7. Фикс и проверка rollback-плана.
