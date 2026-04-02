# 03 — Дополнительные материалы

## Docker Compose Watch (lab/watch/)

`docker compose watch` (Compose 2.22+) — альтернатива bind mount для hot-reload:

```bash
# Запустить в режиме watch
docker compose -f lab/watch/compose.yaml watch

# В другом терминале: изменить файл
echo "<h1>Updated!</h1>" > lab/watch/app/index.html
# → изменение синхронизируется с контейнер за ~1 секунду

# В браузере: http://localhost:8088 — изменение видно сразу
```

**Watch vs Bind mount:**

| Критерий | `watch` (sync) | bind mount |
|---|---|---|
| Скорость | Чуть медленнее | Мгновенно |
| Кросс-платформенность | Да | Проблемы на Mac/Win (VirtIO) |
| Безопасность | Контейнер не видит хост | Контейнер видит хост |
| Rebuild при изменении | Да (action: rebuild) | Нужен restart вручную |

---

## Compose Include (lab/include/)

`include:` (Compose 2.20+) — модуляризация больших compose-файлов:

```bash
# Запуск включает database.yaml + monitoring.yaml
docker compose -f lab/include/compose.yaml up -d

# Увидеть полную конфигурацию после merge
docker compose -f lab/include/compose.yaml config

docker compose -f lab/include/compose.yaml down -v
```

---

## Broken: Circular Dependency (broken/compose-circular-dep.yaml)

```bash
docker compose -f broken/compose-circular-dep.yaml up -d
# Error: circular dependency: service_a → service_b → service_a
```
