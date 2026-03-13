# Docker Lab Progress

## Модули

- [ ] 00-overview — среда, концепции (image, container, layer, registry)
- [ ] 01-basics-cli — lifecycle, stop vs kill, exit codes, docker events
- [ ] 02-images-dockerfile — Dockerfile, .dockerignore, ARG/ENV, dumb-init, HEALTHCHECK
- [ ] 03-compose — multi-container, healthcheck, .env, profiles, override-файлы
- [ ] 04-storage — volumes, bind mounts, backup/restore
- [ ] 05-networking — bridge, DNS, multi-network, port publishing
- [ ] 06-debug-troubleshooting — exit codes, events, систематическая диагностика
- [ ] 07-security — non-root, read-only, cap_drop, secrets, Trivy
- [ ] 08-build-advanced — multi-stage, buildx, distroless, кеш бэкенды
- [ ] 09-registry-release — semver, digest, immutable releases
- [ ] 10-operations-observability — resource limits, log rotation, Prometheus, Grafana, alerts
- [ ] 11-production-patterns — blue/green deployment, nginx proxy
- [ ] 12-capstone-projects — финальные проекты (3 трека)
- [ ] 13-cicd-github-actions — lint → build → test → scan → push

## Готовность к собеседованию

- [ ] Объясняю image vs container и модель слоёв
- [ ] Уверенно читаю `docker inspect`, `docker events`, `docker logs`
- [ ] Знаю exit codes: 0, 1, 127, 137, 143 — что означает каждый
- [ ] Понимаю volume/bind/tmpfs trade-offs
- [ ] Умею multi-stage build и могу объяснить buildx + multi-arch
- [ ] Применяю hardening: non-root, read-only, cap_drop, no-new-privileges
- [ ] Понимаю ограничения Compose и как маппить концепции в Kubernetes
- [ ] Могу написать GitHub Actions workflow: lint → build → test → scan → push
- [ ] Настраивал Prometheus + Grafana для метрик контейнеров
- [ ] Знаю как безопасно передавать секреты (не ENV, не ARG)
