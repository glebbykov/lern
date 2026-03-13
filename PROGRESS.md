# Прогресс обучения

Единый трекер по всем темам репозитория.

---

## Docker — docker-lab/

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

### Готовность к собеседованию по Docker

- [ ] Объясняю image vs container и модель слоёв
- [ ] Уверенно читаю `docker inspect`, `docker events`, `docker logs`
- [ ] Знаю exit codes: 0, 1, 127, 137, 143 — что означает каждый
- [ ] Понимаю volume/bind/tmpfs trade-offs
- [ ] Умею multi-stage build и объясняю buildx + multi-arch
- [ ] Применяю hardening: non-root, read-only, cap_drop, no-new-privileges
- [ ] Понимаю ограничения Compose vs Kubernetes
- [ ] Могу написать GitHub Actions workflow: lint → build → test → scan → push

---

## Kubernetes — k8s-new/k8s-labs/

- [ ] 01-kubectl-basics — основы kubectl
- [ ] 02-pods-lifecycle — жизненный цикл Pod
- [ ] 03-workloads — Deployment, DaemonSet, StatefulSet
- [ ] 04-networking — Services, Ingress, NetworkPolicy
- [ ] 05-storage — PV, PVC, StorageClass
- [ ] 06-scheduling — affinity, taints, tolerations
- [ ] 07-config-security — ConfigMap, Secret, RBAC, PSA
- [ ] 08-observability — метрики, логи, трейсинг
- [ ] 09-helm-gitops — Helm, GitOps-паттерны
- [ ] 10-kubeadm-admin — управление кластером

### Базовые лабы — k8s-lab/

- [ ] 1.lab-begin
- [ ] 2.lab-pods
- [ ] 3.lab-probes
- [ ] 4.lab-replication-controller
- [ ] 5.lab-replication-controller-replica-set
- [ ] 6.lab-job-cron-job

---

## Ansible — ansible-lab/

- [ ] 1 — easy-playbook
- [ ] 2 — multiline string handling
- [ ] 3 — nginx + TLS
- [ ] 4 — inventory
- [ ] 5–6 — переменные (vars)
- [ ] 7–8 — отладка (debug)
- [ ] 9 — роли (roles)
- [ ] 10 — продвинутые роли
- [ ] 11 — сложные сценарии
- [ ] 12 — tasks и handlers
- [ ] 13 — Dockerfile через Ansible
- [ ] 14–16 — docker-compose через Ansible
- [ ] 17 — тестирование с Molecule
- [ ] 18–19 — статический анализ
- [ ] 20 — комплексное задание (capstone)

---

## Linux — linux-beginning/ + lInux-lab-work/

- [ ] live-in-terminal — работа в терминале
- [ ] boot — процесс загрузки, UEFI/BIOS, GRUB
- [ ] disk — управление дисками
- [ ] networking — сетевая конфигурация
- [ ] bridge — сетевые мосты
- [ ] cgroups v2: CPU — linux-lab-work/1
- [ ] cgroups v2: I/O — linux-lab-work/2
- [ ] cgroups v2: Memory — linux-lab-work/3
- [ ] Процессы и демоны — process/
- [ ] linux-screening-prep — подготовка к скринингу

---

## Bash — bash_scripts/

- [ ] level0 — однострочники, bash-checks
- [ ] level1 — базовые скрипты
- [ ] level2 — средний уровень
- [ ] level3 — продвинутые скрипты
- [ ] level4 — экспертный уровень
- [ ] labs — дополнительная практика
- [ ] task1 — конкретные задания

---

## Helm — helm-lab/

- [ ] 1.first-helm3-lab — первый чарт

---

## Git — git-lab-work/

- [ ] 3.git_branching — стратегии ветвления
- [ ] 4.git_on_the_server — серверный Git
- [ ] 7.git_tools — продвинутые инструменты

---

## Сертификация — way-to-SKA/

- [ ] Изучить roadmap CKA
- [ ] Пройти LFS158 (Introduction to Kubernetes)
- [ ] Пройти LFS151/LFS143x
- [ ] Практика на k8s-new/k8s-labs
- [ ] Сдать CKAD
- [ ] Сдать CKA
- [ ] Сдать CKS
