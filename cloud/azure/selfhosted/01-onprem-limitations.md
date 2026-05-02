# 01. Ограничения Azure DevOps Server против Services

Большая часть документации learn.microsoft.com описывает **Azure DevOps Services** (облачный),
не помечая, что часть фич недоступна в on-prem (Server). Этот файл — собранные на практике
различия для текущего развёртывания.

## Не работают вовсе

| Фича | Симптом | Замена для on-prem |
|---|---|---|
| **Universal Packages** | `##[error]Universal Packages are not supported in Azure DevOps Server` | NuGet/npm/Python feed, или PublishBuildArtifacts |
| **PublishPipelineArtifact@1** | `##[error]Pipeline Artifact Task is not supported in on-premises` | `PublishBuildArtifacts@1` |
| **Auditing** (детальный) | вкладка отсутствует в Project settings | Только базовые `createdBy/modifiedBy` поля |
| **Service Hooks → Microsoft Teams (Incoming webhook)** | работает не везде | Web Hooks (generic POST) |
| **Approval gate через `pipelinePermissions` API** | 401 Unauthorized даже у админа | Permit-клик в UI вручную |

## Работают, но иначе

| Что | В Services | В Server |
|---|---|---|
| URL API | `https://dev.azure.com/{org}/{proj}/_apis/...` | `http://server/{collection}/{proj}/_apis/...` (обязательно `DefaultCollection`) |
| `_apis/connectionData` без коллекции | 200 | 401 |
| api-version для checks/approvals | `7.1` | `6.0-preview.1` (preview!) |
| Public URL в API ответах | реальный | внутренний hostname (`ec2amaz-auoc24e`), снаружи не открывается |
| Web UI host | один | "Public URL" может отличаться от "Server URL" — настраивается в Administration Console на VM |

## Authentication через PAT

В обоих случаях работает Basic auth:
```bash
curl -u ":$PAT" "$BASE/..."
```
- Username — пустой
- Password — PAT
- Scope в PAT обязательно расширяй явно: `Code (R/W)`, `Build (R/W)`, `Release (R/W)`, `Agent Pools (R/W)`,
  `Service Connections (R/W)`. Для работы с Environments нужен **`Environment (Read & manage)`**, иначе
  `pipelinePermissions/environment/{id}` возвращает 401.

## Trusted Capabilities у агента

`my-agent` (Windows) имеет в capabilities только то, что нашёл при запуске `config.cmd`:
- `python` найден (3.15)
- `git` найден (2.x)
- `nssm` — **нет** (надо `choco install nssm` руками, см. лабу 06)
- `Docker` — нет
- `aws` CLI — нет

Можно просмотреть на http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/_admin/_AgentPool →
выбрать pool → Agent → вкладка Capabilities. Кастомные capabilities добавляются там же кнопкой
**Add capability** — потом в YAML использовать через `demands:`.

## Что сохранено как есть

- YAML schema идентичный, кроме недоступных tasks
- pytest, gunicorn, waitress — всё работает
- Triggers (CI/PR), conditions, runtime parameters — работают
- Variable groups, secret variables, masking в логах — работают
- Build retention policy — работает (Project settings → Pipelines → Retention)

## Литература

- Сравнение Services vs Server (официальное): https://learn.microsoft.com/azure/devops/server/release-notes/azuredevops2022-comparison
- Известные ограничения: https://learn.microsoft.com/azure/devops/server/troubleshoot/known-issues
