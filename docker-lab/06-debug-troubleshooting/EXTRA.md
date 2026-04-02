# 06 — Дополнительные сценарии

## Сценарий 14: CPU Throttling

Контейнер ограничен до 5% CPU → работает, но заметно тормозит.

```bash
docker compose -f broken/compose-cpu-throttle.yaml up -d

# Диагностика
docker stats --no-stream dbg-cpu-throttle
# CPU%: ~5% — процесс ограничен

docker inspect dbg-cpu-throttle --format '{{.HostConfig.NanoCpus}}'
# 50000000 (0.05 * 1e9)

docker compose -f broken/compose-cpu-throttle.yaml down
```

**Симптом в production:** приложение отвечает, но латенция выросла в 10x.
**Диагностика:** `docker stats` → CPU% ≈ limit → увеличить `cpus`.

---

## Сценарий 15: PID Limit

`pids_limit: 5` → контейнер не может fork-нуть более 5 процессов.

```bash
docker compose -f broken/compose-pid-limit.yaml up

# В логах:
# sh: can't fork: Resource temporarily unavailable

docker inspect dbg-pid-limit --format '{{.HostConfig.PidsLimit}}'
# 5

docker compose -f broken/compose-pid-limit.yaml down
```

**Симптом в production:** fork bomb / утечка горутин / утечка процессов.
**Диагностика:** `docker inspect` → `PidsLimit`, `docker top` → количество процессов.

---

## Сценарий 16: Zombie Processes

Shell (sh) как PID 1 не обрабатывает SIGCHLD → дочерние процессы становятся зомби.

```bash
docker compose -f broken/compose-zombie.yaml up -d
sleep 5

# Посмотреть процессы — зомби имеют статус Z
docker exec dbg-zombie ps aux
# PID   STATUS    COMMAND
# ...   Z         [sh] <defunct>   ← зомби

docker compose -f broken/compose-zombie.yaml down
```

**Fix:** добавить `init: true` в compose или `--init` в `docker run`.
Это запускает `tini` как PID 1, который reap-ит зомби.

```yaml
services:
  app:
    init: true    # ← fix
```
