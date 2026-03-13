# DevOps Lab

Практические лабораторные работы по DevOps и инфраструктурным технологиям.

> Папку репозитория стоит переименовать: `lern` → `devops-lab` (закрыть VSCode, переименовать в файловом менеджере, открыть снова).

---

## Темы и разделы

### Docker

| Ресурс                                                    | Описание                                               |
| --------------------------------------------------------- | ------------------------------------------------------ |
| [docker-lab/](./docker-lab/README.md)                     | Полный курс: 13 модулей от основ до production-паттернов |
| [docker-lab/progress.md](./docker-lab/progress.md)        | Трекер прогресса по модулям                            |

overview → cli → dockerfile → compose → storage → networking → debug → security → build → registry → observability → production → capstone

---

### Kubernetes

| Ресурс                                                        | Описание                                        |
| ------------------------------------------------------------- | ----------------------------------------------- |
| [k8s-new/k8s-labs/](./k8s-new/k8s-labs/)                     | Основной K8s-курс: 10 модулей + проекты         |
| [k8s-new/k8s-labs/modules/10-kubeadm-admin/setup-guide.md](./k8s-new/k8s-labs/modules/10-kubeadm-admin/setup-guide.md) | Установка кластера kubeadm (Yandex Cloud / Debian 12) |
| [way-to-SKA/](./way-to-SKA/)                                  | Путь к CKA/CKAD/CKS сертификации                |
| [k8s-new/k8s-interviews/](./k8s-new/k8s-interviews/)          | Вопросы к собеседованию                         |

kubectl → pods → workloads → networking → storage → scheduling → config/security → observability → helm/gitops → kubeadm

---

### Ansible

| Ресурс                                                              | Описание                                              |
| ------------------------------------------------------------------- | ----------------------------------------------------- |
| [ansible-lab/](./ansible-lab/)                                      | 20 прогрессивных модулей: от основ до molecule        |
| [ansible-interview-questions/](./ansible-interview-questions/)      | 40 вопросов к собеседованию                           |

playbooks → inventory → vars → debug → roles → handlers → docker-compose → molecule → static analysis

---

### Linux

| Ресурс                              | Описание                                   |
| ----------------------------------- | ------------------------------------------ |
| [linux-beginning/](./linux-beginning/) | Основы: терминал, boot, диск, сеть, bridge |
| [lInux-lab-work/](./lInux-lab-work/)  | cgroups v2: CPU, I/O, Memory               |
| [process/](./process/)              | Демоны, сигналы (SIGHUP)                   |
| [la/](./la/)                        | Linux administration: swap и др.           |

---

### Bash / Scripting

| Ресурс                                                          | Описание                                    |
| --------------------------------------------------------------- | ------------------------------------------- |
| [bash_scripts/](./bash_scripts/)                                | Уровни level0–level7: от основ до production-ready |
| [bash_scripts/user_add.sh](./bash_scripts/user_add.sh)          | Скрипт создания пользователя с sudo         |
| [generate-logs/](./generate-logs/)                              | Утилиты для генерации логов                 |

---

### Helm

| Ресурс                   | Описание                           |
| ------------------------ | ---------------------------------- |
| [helm-lab/](./helm-lab/) | Введение в Helm 3, первый чарт     |

---

### Git

| Ресурс                           | Описание                                       |
| -------------------------------- | ---------------------------------------------- |
| [git-lab-work/](./git-lab-work/) | Branching, server-side Git, advanced tools     |

---

### Ссылки и референсы

| Ресурс             | Описание                                           |
| ------------------ | -------------------------------------------------- |
| [links/](./links/) | Коллекция ссылок: ZFS, Docker, K8s, DevOps roadmap |

---

## Рекомендуемый маршрут обучения

```text
1. linux-beginning/       → основы ОС и CLI
2. bash_scripts/          → автоматизация (level0 → level7)
3. docker-lab/            → контейнеры (00 → 12)
4. ansible-lab/           → configuration management
5. k8s-new/k8s-labs/      → оркестрация (01 → 10)
6. helm-lab/              → пакетный менеджер K8s
7. way-to-SKA/            → подготовка к CKA
```

---

## CI/CD

Репозиторий использует GitHub Actions для автоматической проверки:

- **hadolint** — линтинг Dockerfile
- **yamllint** — проверка YAML
- **shellcheck** — анализ bash-скриптов
- **compose validation** — тестирование docker-compose файлов

Пайплайн: [.github/workflows/docker-lab-ci.yml](./.github/workflows/docker-lab-ci.yml)
