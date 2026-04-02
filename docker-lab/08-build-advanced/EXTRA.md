# 08 — Дополнительные материалы

## Docker Buildx Bake (lab/bake/)

Параллельная сборка нескольких образов из одного HCL-файла:

```bash
# Показать план сборки (dry-run)
docker buildx bake -f lab/bake/docker-bake.hcl --print

# Собрать все targets параллельно
docker buildx bake -f lab/bake/docker-bake.hcl

# Собрать конкретный target
docker buildx bake -f lab/bake/docker-bake.hcl api

# С переменными
TAG=1.0.0 docker buildx bake -f lab/bake/docker-bake.hcl
```

**Bake vs docker-compose build:**

| Критерий | `docker compose build` | `docker buildx bake` |
|---|---|---|
| Формат | YAML (compose.yaml) | HCL / JSON / YAML |
| Параллельность | Да (с 2.23+) | Да (изначально) |
| Переменные | Ограничено | Полноценный HCL |
| Multi-platform | Через profiles | Нативно |
| Cache backends | Базовый | registry, local, gha, s3 |

---

## Broken: SSH Key Leaked via ARG (broken/Dockerfile.build-secrets-leak)

```bash
# Собрать с ARG (ОПАСНО!)
docker build --build-arg SSH_KEY="fake-ssh-key" \
  -f broken/Dockerfile.build-secrets-leak .

# Утечка видна в docker history
docker history <image> --no-trunc | grep SSH_KEY
# → SSH_KEY=fake-ssh-key  ← УТЕЧКА!

# Fix: использовать --mount=type=ssh
# RUN --mount=type=ssh git clone git@github.com:org/repo.git
```
