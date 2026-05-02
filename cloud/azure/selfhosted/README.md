# Self-hosted Azure DevOps Labs

Лабораторные работы и заметки по работе с **Azure DevOps Server** (on-premises) на учебном
развёртывании `http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/`. Дополняют
`cloud/azure/GUIDE.md` и `cloud/azure/GUIDE2.md` — разбирают то, что **не работает** на on-prem
вовсе, или работает иначе чем в облачном Azure DevOps Services.

## Окружение

| | |
|---|---|
| Сервер | Windows EC2 `ec2-16-16-121-34.eu-north-1.compute.amazonaws.com` |
| Версия | Azure DevOps Server 2022 (agent v3.236.x) |
| Коллекция | `DefaultCollection` |
| Проект | `Lern-azure` |
| Репозиторий | `azure-repo` (этот) |
| Pool | `self-hosted-pool`, 1 агент `my-agent` (online) |
| Environments | `staging` (id=1), `production` (id=2, с Approval Gate) |
| Variable Groups | `app-secrets` (id=2) с `APP_SECRET_KEY` |
| Целевой деплой | `C:\app\hello-cicd` (staging:8080), `C:\app\hello-cicd-prod` (production:8081) |

## Содержание

| # | Тема | Статус |
|---|---|---|
| 01 | [Ограничения on-prem против Services](01-onprem-limitations.md) | 📖 справочник |
| 02 | [Variable Groups + masked secrets](02-variable-groups.md) | ✅ выполнено на сервере |
| 03 | [Rollback через локальный архив](03-rollback-archive.md) | ✅ выполнено на сервере |
| 04 | [Pipeline templates (refactor)](04-pipeline-templates.md) | ✅ выполнено на сервере |
| 05 | [Pull Request + Branch Policies](05-pr-branch-policies.md) | 📝 пошаговое упражнение |
| 06 | [Реальный запуск Flask (waitress + nssm)](06-real-service-deploy.md) | 📝 подробная инструкция, требует RDP+AWS |
| 07 | [Multi-environment + Approval Gate (production)](07-multi-environment-approval.md) | ✅ environment создан, YAML обновлён |

## Как читать

1. **Справочник 01** — прочти первым, экономит часы на дебаге "почему таска не работает на on-prem".
2. **Лабы 02-04, 07** — то, что **уже сделано** на сервере. Открой соответствующие места в UI и потыкай.
3. **Лабы 05, 06** — пошаговые упражнения, которые нужно сделать самому (требуют доступа, которого нет у автоматизации).

## Граф зависимостей лаб

```
01 (справочник, читать всегда)
  ↓
02 ──────────► 04 ──────────► 07 (требует 02 для секрета production)
03 ──────────────────────────► 07 (использует тот же rollback подход)
05 (независимая, про branch policies)
06 ──────────► 07 (production деплой использует nssm/waitress из 06)
```

## Сводка ссылок UI на текущем сервере

- Список пайплайнов — http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_build
- Library (variable groups) — http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_library
- Environments — http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_environments
- Repos / azure-repo — http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_git/azure-repo
- Agent pool — http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/_admin/_AgentPool
- PR-ы — http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_git/azure-repo/pullrequests

## Changelog

- 2026-05-02: первоначальный набор лаб 01-06
- 2026-05-02: добавлена лаба 07 (multi-environment + production approval); расширена лаба 06 (детальный гайд по nssm/waitress/AWS SG)
