# Azure DevOps CI/CD: Полное руководство с CLI

Пошаговая инструкция по настройке репозитория, pipeline и деплоя в Azure App Service через Azure CLI.  
Каждый шаг содержит команду, объяснение и ссылку на официальную документацию.

---

## Содержание

1. [Предварительные требования](#1-предварительные-требования)
2. [Установка и авторизация Azure CLI](#2-установка-и-авторизация-azure-cli)
3. [Создание Azure DevOps проекта и репозитория](#3-создание-azure-devops-проекта-и-репозитория)
4. [Создание приложения](#4-создание-приложения)
5. [Создание Azure-ресурсов](#5-создание-azure-ресурсов)
6. [Настройка Service Principal и Service Connection](#6-настройка-service-principal-и-service-connection)
7. [Настройка self-hosted агента](#7-настройка-self-hosted-агента)
8. [Pipeline YAML: CI/CD конфигурация](#8-pipeline-yaml-cicd-конфигурация)
9. [Создание pipeline через CLI](#9-создание-pipeline-через-cli)
10. [Авторизация ресурсов pipeline](#10-авторизация-ресурсов-pipeline)
11. [Настройка Environment с Approval Gate](#11-настройка-environment-с-approval-gate)
12. [Результат](#12-результат)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Предварительные требования

| Требование | Описание |
|---|---|
| Azure CLI >= 2.50 | Основной инструмент управления Azure |
| Azure DevOps Extension | `az extension add --name azure-devops` |
| Azure аккаунт | Подписка с правами Contributor |
| Azure DevOps организация | Создаётся на dev.azure.com |
| Personal Access Token (PAT) | Для CLI-авторизации в DevOps |
| Python 3.11+ | Для self-hosted агента и приложения |

**Официальная документация:**
- [Установка Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure DevOps CLI extension](https://learn.microsoft.com/azure/devops/cli/index)

---

## 2. Установка и авторизация Azure CLI

```bash
# Проверить версию CLI и установленные расширения
az version

# Установить расширение Azure DevOps
az extension add --name azure-devops

# Авторизоваться в Azure (откроет браузер)
az login

# Посмотреть доступные подписки
az account list --output table

# Выбрать нужную подписку
az account set --subscription "<SUBSCRIPTION_ID>"

# Проверить текущую подписку
az account show --output table
```

> **Лучшая практика:** Используй `az account set` явно — это предотвращает случайные изменения не в той подписке.

**Документация:**
- [az login](https://learn.microsoft.com/cli/azure/reference-index#az-login)
- [az account](https://learn.microsoft.com/cli/azure/account)

---

## 3. Создание Azure DevOps проекта и репозитория

```bash
# Авторизовать CLI в Azure DevOps через PAT
# PAT нужен с правами: Agent Pools (R/W), Build (R/W), Code (R/W),
#                      Release (R/W), Service Connections (R/W)
# Для полной автоматизации без Permit в UI добавь: Environment (Read & manage)
export AZURE_DEVOPS_EXT_PAT="<YOUR_PAT>"

# Установить организацию по умолчанию (замени на свою)
az devops configure --defaults organization=https://dev.azure.com/<ORG_NAME>

# Создать новый проект (если нет существующего)
az devops project create \
  --name "hello-cicd-demo" \
  --visibility private \
  --source-control git

# Или выбрать существующий проект
az devops configure --defaults project="<PROJECT_NAME>"

# Создать репозиторий в проекте
az repos create --name "hello-cicd-app"

# Посмотреть URL репозитория
az repos show --repository "hello-cicd-app" --query remoteUrl -o tsv
```

> **Лучшая практика:** `az devops configure --defaults` сохраняет org/project в `~/.azure/azuredevops/config` — не нужно передавать `--org` и `--project` в каждую команду.

**Документация:**
- [Создание проекта](https://learn.microsoft.com/azure/devops/organizations/projects/create-project)
- [az devops configure](https://learn.microsoft.com/cli/azure/devops#az-devops-configure)
- [az repos create](https://learn.microsoft.com/cli/azure/repos#az-repos-create)

---

## 4. Создание приложения

Структура проекта:

```
hello-cicd-app/
├── app.py                  # Flask-приложение
├── requirements.txt        # Зависимости (pinned versions)
├── tests/
│   ├── __init__.py         # Обязательно! Без него pytest не найдёт app.py
│   └── test_app.py         # Тесты pytest
├── .gitignore
└── azure-pipelines.yml     # CI/CD pipeline
```

### app.py

```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({"message": "Hello, Azure DevOps CI/CD!", "status": "ok"})

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

### requirements.txt

```
# Лучшая практика: фиксируй ТОЧНЫЕ версии (==) для воспроизводимости
flask==3.1.0
gunicorn==23.0.0
pytest==8.3.5
pytest-flask==1.3.0
pytest-cov==6.1.0
```

### tests/test_app.py

```python
import pytest
from app import app

@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

def test_index(client):
    response = client.get("/")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"

def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "healthy"
```

### Первый коммит

```bash
# Инициализировать локальный репозиторий
git init
git remote add origin https://<ORG_NAME>@dev.azure.com/<ORG_NAME>/<PROJECT>/_git/hello-cicd-app

# Лучшая практика: Conventional Commits — структурированные сообщения коммитов
# Формат: <type>(<scope>): <description>
# Типы: feat, fix, docs, chore, refactor, test, ci

git add app.py requirements.txt tests/ .gitignore
git commit -m "feat: initial Flask app with health endpoint"
git push -u origin main

# ВАЖНО: tests/__init__.py обязателен!
# Без него pytest не добавляет корень проекта в sys.path и падает с:
# ModuleNotFoundError: No module named 'app'
touch tests/__init__.py
git add tests/__init__.py
git commit -m "fix: add tests/__init__.py for pytest import resolution"
git push origin main
```

**Документация:**
- [Conventional Commits](https://www.conventionalcommits.org/)
- [pytest-flask](https://pytest-flask.readthedocs.io/)

---

## 5. Создание Azure-ресурсов

```bash
# Переменные — лучшая практика: определи один раз, используй везде
LOCATION="westeurope"           # Регион датацентра
RG="rg-hello-cicd"             # Resource Group
APP_PLAN="plan-hello-cicd"     # App Service Plan
APP_NAME="hello-cicd-app-gleb" # Имя должно быть глобально уникальным

# 1. Создать Resource Group
az group create --name $RG --location $LOCATION

# 2. Создать App Service Plan (F1 = бесплатный тир)
az appservice plan create \
  --name $APP_PLAN \
  --resource-group $RG \
  --sku F1 \
  --is-linux

# 3. Создать Web App (Python 3.11 на Linux)
az webapp create \
  --name $APP_NAME \
  --resource-group $RG \
  --plan $APP_PLAN \
  --runtime "PYTHON:3.11"

# 4. Настроить startup command (gunicorn для production)
az webapp config set \
  --name $APP_NAME \
  --resource-group $RG \
  --startup-file "gunicorn --bind=0.0.0.0:8000 app:app"

# Проверить что приложение доступно (вернёт HTML страницу)
az webapp show \
  --name $APP_NAME \
  --resource-group $RG \
  --query defaultHostName -o tsv
```

> **Лучшая практика:** F1 — бесплатный тир, подходит для учебных проектов. Для production используй минимум B1 (Basic) или выше.

> **Лучшая практика:** Используй `--is-linux` для Python-приложений — Windows App Service для Python не рекомендуется.

**Документация:**
- [az group create](https://learn.microsoft.com/cli/azure/group#az-group-create)
- [az appservice plan create](https://learn.microsoft.com/cli/azure/appservice/plan#az-appservice-plan-create)
- [az webapp create](https://learn.microsoft.com/cli/azure/webapp#az-webapp-create)
- [App Service pricing](https://azure.microsoft.com/pricing/details/app-service/linux/)

---

## 6. Настройка Service Principal и Service Connection

Service Principal — это "технический пользователь" для pipeline. Принцип минимальных привилегий: даём права только на нужный Resource Group.

```bash
# Получить ID подписки
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# 1. Создать Service Principal с правами Contributor на Resource Group
# (не на всю подписку — лучшая практика: минимальные привилегии)
az ad sp create-for-rbac \
  --name "sp-hello-cicd-pipeline" \
  --role Contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-hello-cicd" \
  --output json

# Вывод содержит: appId, password, tenant — сохрани в безопасном месте!
# {
#   "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "displayName": "sp-hello-cicd-pipeline",
#   "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
#   "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# }

# 2. Создать Service Connection в Azure DevOps
# (соединяет pipeline с Azure-подпиской через Service Principal)
export AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY="<password_из_шага_выше>"

az devops service-endpoint azurerm create \
  --azure-rm-service-principal-id "<appId>" \
  --azure-rm-subscription-id "$SUBSCRIPTION_ID" \
  --azure-rm-subscription-name "<имя_подписки>" \
  --azure-rm-tenant-id "<tenant>" \
  --name "azure-service-connection" \
  --output json

# 3. Разрешить использование Service Connection всеми pipeline
ENDPOINT_ID=$(az devops service-endpoint list \
  --query "[?name=='azure-service-connection'].id" -o tsv)

az devops service-endpoint update \
  --id $ENDPOINT_ID \
  --enable-for-all true
```

> **Лучшая практика:** Никогда не используй `--scopes /subscriptions/ID` (права на всю подписку). Ограничивай правами на конкретный Resource Group или ниже.

> **Лучшая практика:** Имя `azure-service-connection` должно точно совпадать с `azureSubscription` в pipeline YAML.

**Документация:**
- [az ad sp create-for-rbac](https://learn.microsoft.com/cli/azure/ad/sp#az-ad-sp-create-for-rbac)
- [Service connections overview](https://learn.microsoft.com/azure/devops/pipelines/library/service-endpoints)
- [az devops service-endpoint azurerm create](https://learn.microsoft.com/cli/azure/devops/service-endpoint/azurerm#az-devops-service-endpoint-azurerm-create)

---

## 7. Настройка self-hosted агента

С 2023 года Microsoft отключила бесплатные параллельные задания для новых организаций. Self-hosted агент решает это бесплатно.

```bash
# 1. Создать пул агентов в Azure DevOps
az pipelines pool create --name "self-hosted-pool" --output json

# 2. Создать системного пользователя для агента
# ВАЖНО: агент не должен работать под root
sudo useradd -m -s /bin/bash azagent
sudo mkdir -p /home/azagent/agent
sudo chown azagent:azagent /home/azagent/agent

# 3. Скачать последнюю версию агента
# Актуальные релизы: https://github.com/microsoft/azure-pipelines-agent/releases
cd /home/azagent/agent
sudo -u azagent curl -L -o agent.tar.gz \
  "https://vstsagentpackage.azureedge.net/agent/4.271.0/vsts-agent-linux-x64-4.271.0.tar.gz"
sudo -u azagent tar -xzf agent.tar.gz
sudo -u azagent rm agent.tar.gz

# 4. Настроить агент (unattended — без интерактивных вопросов)
sudo -u azagent ./config.sh \
  --unattended \
  --url "https://dev.azure.com/<ORG_NAME>" \
  --auth pat \
  --token "<YOUR_PAT>" \
  --pool "self-hosted-pool" \
  --agent "$(hostname)-agent" \
  --acceptTeeEula

# 5. Установить как systemd-сервис и запустить
sudo ./svc.sh install azagent
sudo ./svc.sh start

# Проверить статус
sudo ./svc.sh status

# Проверить что агент онлайн в DevOps
az pipelines agent list --pool-id <POOL_ID> --output table
```

> **Лучшая практика:** Всегда создавай отдельного пользователя для агента. Запуск агента под root — угроза безопасности.

> **Лучшая практика:** Используй `svc.sh install` для автостарта при перезагрузке сервера.

> **Важно:** На self-hosted агенте НЕ используй задачу `UsePythonVersion@0` — она предназначена для Microsoft-hosted агентов и пытается скачать Python из GitHub. Используй системный `python3` напрямую.

**Документация:**
- [Self-hosted Linux agents](https://learn.microsoft.com/azure/devops/pipelines/agents/linux-agent)
- [Agent pools](https://learn.microsoft.com/azure/devops/pipelines/agents/pools-queues)
- [Releases (GitHub)](https://github.com/microsoft/azure-pipelines-agent/releases)

---

## 8. Pipeline YAML: CI/CD конфигурация

Файл `azure-pipelines.yml` лежит в репозитории рядом с кодом — это и есть Pipeline-as-Code.

```yaml
# azure-pipelines.yml

# ─── ТРИГГЕРЫ ────────────────────────────────────────────────────────────────
trigger:
  branches:
    include:
      - main          # CI запускается при каждом push в main
  paths:
    exclude:
      - "*.md"        # Изменения в документации не запускают билд

pr:
  branches:
    include:
      - main          # Проверяем каждый Pull Request перед мержем в main

# ─── ПЕРЕМЕННЫЕ ──────────────────────────────────────────────────────────────
variables:
  pythonVersion: "3.11"  # Версия Python в одном месте — удобно обновлять
  # Примечание: эта переменная служит документацией.
  # На self-hosted агенте Python уже установлен системно, поэтому
  # скрипты используют python3 напрямую, а не $(pythonVersion).
  # Значение должно совпадать с --runtime "PYTHON:X.XX" из шага 5.

# ─── STAGES ──────────────────────────────────────────────────────────────────
# Лучшая практика: разделяй CI (Build+Test) и CD (Deploy) на отдельные stages
# Это позволяет перезапустить только Deploy без пересборки

stages:

# ── STAGE 1: CI ──────────────────────────────────────────────────────────────
  - stage: CI
    displayName: "Build & Test"
    jobs:
      - job: build_and_test
        displayName: "Install, Lint & Test"
        pool:
          name: "self-hosted-pool"  # Имя пула из шага 7

        steps:

          # Шаг 1: Создать venv и установить зависимости
          # Лучшая практика: venv изолирует зависимости между сборками
          - script: |
              python3 -m venv .venv
              source .venv/bin/activate
              python3 -m pip install --upgrade pip
              pip install -r requirements.txt
            displayName: "Create venv & install dependencies"

          # Шаг 2: Тесты с покрытием
          # --junitxml — для PublishTestResults
          # --cov-report=xml — для PublishCodeCoverageResults
          - script: |
              source .venv/bin/activate
              mkdir -p junit
              pytest tests/ \
                --junitxml=junit/test-results.xml \
                --cov=. \
                --cov-report=xml:coverage.xml \
                -v
            displayName: "Run tests with coverage"

          # Шаг 3: Публикация результатов тестов в UI DevOps
          - task: PublishTestResults@2
            displayName: "Publish test results"
            condition: succeededOrFailed()  # Публикуем даже если тесты упали
            inputs:
              testResultsFormat: "JUnit"
              testResultsFiles: "junit/test-results.xml"
              failTaskOnFailedTests: true   # Pipeline упадёт если тесты не прошли

          # Шаг 4: Публикация покрытия
          - task: PublishCodeCoverageResults@2
            displayName: "Publish code coverage"
            condition: succeededOrFailed()
            inputs:
              codeCoverageTool: "Cobertura"
              summaryFileLocation: "coverage.xml"

          # Шаг 5: Создать ZIP-архив артефакта
          # Лучшая практика: один артефакт деплоится во все окружения
          - task: ArchiveFiles@2
            displayName: "Archive application"
            inputs:
              rootFolderOrFile: "$(Build.SourcesDirectory)"
              includeRootFolder: false
              archiveType: "zip"
              archiveFile: "$(Build.ArtifactStagingDirectory)/app-$(Build.BuildId).zip"
              replaceExistingArchive: true
              excludePaths: |
                .git
                .venv
                venv
                __pycache__
                tests
                junit
                *.md

          # Шаг 6: Опубликовать артефакт для CD stage
          - task: PublishBuildArtifacts@1
            displayName: "Publish artifact"
            inputs:
              PathtoPublish: "$(Build.ArtifactStagingDirectory)"
              ArtifactName: "app-package"
              publishLocation: "Container"

# ── STAGE 2: CD ──────────────────────────────────────────────────────────────
  - stage: CD
    displayName: "Deploy to Staging"
    dependsOn: CI                          # Запускается только после успешного CI
    condition: |
      and(
        succeeded(),
        eq(variables['Build.SourceBranch'], 'refs/heads/main')
      )
    # Лучшая практика: деплой только из main, не из PR-веток
    jobs:
      - deployment: deploy_staging
        displayName: "Deploy to Azure App Service"
        environment: "staging"             # Environments: история деплоев + approval gates
        pool:
          name: "self-hosted-pool"
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: app-package
                  displayName: "Download artifact"

                # Деплой через Azure CLI
                # Лучшая практика: AzureCLI@2 + az webapp deploy надёжнее на F1-тире
                # (нет конфликтов блокировки файлов в отличие от zipDeploy)
                - task: AzureCLI@2
                  displayName: "Deploy to App Service"
                  inputs:
                    azureSubscription: "azure-service-connection"
                    scriptType: "bash"
                    scriptLocation: "inlineScript"
                    inlineScript: |
                      az webapp deploy \
                        --resource-group rg-hello-cicd \
                        --name hello-cicd-app-gleb \
                        --src-path "$(Pipeline.Workspace)/app-package/app-$(Build.BuildId).zip" \
                        --type zip \
                        --async false \
                        --timeout 300
```

**Ключевые концепции:**

| Концепция | Зачем |
|---|---|
| `trigger.paths.exclude` | Не запускать CI на изменения в `.md` файлах |
| `pr` trigger | Проверять код до мержа в main |
| Stages CI/CD | Перезапускать только Deploy без пересборки |
| `condition` на CD stage | Деплоить только из main, не из PR |
| `environment: staging` | История деплоев + Approval Gates |
| `condition: succeededOrFailed()` | Публиковать результаты тестов даже если они упали |
| `PublishBuildId` в имени архива | Уникальное имя артефакта для каждой сборки |

**Документация:**
- [YAML schema reference](https://learn.microsoft.com/azure/devops/pipelines/yaml-schema)
- [Triggers](https://learn.microsoft.com/azure/devops/pipelines/build/triggers)
- [Stages](https://learn.microsoft.com/azure/devops/pipelines/process/stages)
- [Environments](https://learn.microsoft.com/azure/devops/pipelines/process/environments)
- [PublishTestResults@2](https://learn.microsoft.com/azure/devops/pipelines/tasks/test/publish-test-results)
- [PublishCodeCoverageResults@2](https://learn.microsoft.com/azure/devops/pipelines/tasks/test/publish-code-coverage-results)
- [ArchiveFiles@2](https://learn.microsoft.com/azure/devops/pipelines/tasks/utility/archive-files)
- [AzureCLI@2](https://learn.microsoft.com/azure/devops/pipelines/tasks/deploy/azure-cli)

---

## 9. Создание pipeline через CLI

```bash
# Закоммитить pipeline файл в репозиторий
git add azure-pipelines.yml
git commit -m "ci: add Azure Pipelines CI/CD configuration"
git push origin main

# Создать pipeline из YAML-файла в репозитории
az pipelines create \
  --name "hello-cicd-pipeline" \
  --repository "hello-cicd-app" \
  --repository-type tfsgit \
  --branch main \
  --yml-path azure-pipelines.yml \
  --skip-first-run true    # Не запускать сразу — сначала настроим авторизации (шаг 10)

# Посмотреть список pipeline
az pipelines list --output table
```

> **ВАЖНО:** Не запускай pipeline до шага 10. Если запустить раньше, чем авторизован agent pool, pipeline встанет на `Checkpoint.Authorization` ещё и для пула агентов — придётся нажимать Permit дважды: для пула и для environment. Сначала выполни шаг 10, затем возвращайся сюда.

```bash
# Запустить pipeline вручную — ТОЛЬКО ПОСЛЕ шага 10
az pipelines run --name "hello-cicd-pipeline" --branch main

# Следить за выполнением
az pipelines runs list --pipeline-name "hello-cicd-pipeline" --output table
```

**Документация:**
- [az pipelines create](https://learn.microsoft.com/cli/azure/pipelines#az-pipelines-create)
- [az pipelines run](https://learn.microsoft.com/cli/azure/pipelines#az-pipelines-run)

---

## 10. Авторизация ресурсов pipeline

При первом запуске pipeline нужно разрешить доступ к пулу агентов через REST API.

```bash
# Получить ID пула агентов
POOL_ID=$(az pipelines pool show \
  --pool-name "self-hosted-pool" \
  --query id -o tsv)

# Разрешить всем pipeline использовать пул через REST API
# ВАЖНО: на Linux base64 по умолчанию переносит строку на 76 символах —
# используй -w 0 чтобы получить одну строку (иначе Authorization header сломается)
curl -s -X PATCH \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $(printf ':%s' "$AZURE_DEVOPS_EXT_PAT" | base64 -w 0)" \
  "https://dev.azure.com/<ORG_NAME>/<PROJECT_NAME>/_apis/pipelines/pipelinePermissions/queue/$POOL_ID?api-version=7.1-preview.1" \
  -d '{"allPipelines":{"authorized":true}}'
```

> **Примечание:** В Azure DevOps UI это делается через Settings → Agent Pools → Security → "Grant access permission to all pipelines".

> **Что ещё авторизуется автоматически:** Service Connection авторизуется на шаге 6 командой `az devops service-endpoint update --enable-for-all true`. Environment авторизуется отдельно — см. шаг 11.

**Документация:**
- [Pipeline permissions REST API](https://learn.microsoft.com/rest/api/azure/devops/approvalsandchecks/pipeline-permissions)

---

## 11. Настройка Environment с Approval Gate

Environment `staging` создаётся автоматически при первом запуске pipeline с `environment: "staging"` в YAML. При первом деплое система покажет `Checkpoint.Authorization` и остановится — нужно однократно нажать **Permit** в UI.

```bash
# Создать Environment явно (опционально — создаётся автоматически при первом запуске)
# ВАЖНО: правильный --area это "distributedtask", не "environments"
# ВАЖНО: api-version должен быть "7.1" (без суффикса "-preview.1" — CLI его не принимает)
az devops invoke \
  --area distributedtask \
  --resource environments \
  --route-parameters project="<PROJECT_NAME>" \
  --http-method POST \
  --in-file <(echo '{"name":"staging","description":"Staging environment"}') \
  --api-version "7.1" \
  --output json

# Список environments
az devops invoke \
  --area distributedtask \
  --resource environments \
  --route-parameters project="<PROJECT_NAME>" \
  --http-method GET \
  --api-version "7.1" \
  --output json
```

> **Важно: авторизация pipeline для Environment через API.**
> API `PATCH pipelinePermissions/environment/{id}` возвращает 401 даже при PAT с "Full Access",
> если у токена не выдан явный скоуп **"Environment (Read & manage)"**.
> Обходной путь — нажать Permit в UI при первом запуске (однократно).
> Все последующие запуски идут без остановки.

**Однократный Permit при первом запуске:**

При первом использовании нового Environment pipeline остановится на `Checkpoint.Authorization`.
В UI перейди по ссылке запуска и нажми **Permit**:

```
Pipelines → [текущий запуск] → "This pipeline needs permission to access a resource" → Permit
```

После первого Permit pipeline продолжит деплой автоматически. Повторного подтверждения не потребуется.

**Добавить Approval Gate через UI:**
1. Azure DevOps → Pipelines → Environments → staging
2. Кнопка "..." → Approvals and checks
3. Add → Approvals → указать approver
4. Save

> **Лучшая практика:** Approval Gate на staging окружении — обязательная остановка перед деплоем. Даёт время проверить что CI прошёл корректно.

**Документация:**
- [Environments](https://learn.microsoft.com/azure/devops/pipelines/process/environments)
- [Approvals and checks](https://learn.microsoft.com/azure/devops/pipelines/process/approvals)

---

## 12. Результат

После настройки всего вышеперечисленного pipeline работает следующим образом:

```
git push origin main
       │
       ▼
┌─────────────┐
│  CI Stage   │
│  ─────────  │
│  venv + pip │
│  pytest ✓   │
│  coverage   │
│  zip архив  │
│  артефакт   │
└──────┬──────┘
       │ succeeded() + branch == main
       ▼
┌─────────────┐
│  CD Stage   │   (только из main)
│  ─────────  │
│  download   │
│  az webapp  │
│  deploy ✓   │
└──────┬──────┘
       │
       ▼
https://hello-cicd-app-gleb.azurewebsites.net
```

**Проверить деплой:**
```bash
curl https://hello-cicd-app-gleb.azurewebsites.net/
# {"message": "Hello, Azure DevOps CI/CD!", "status": "ok"}

curl https://hello-cicd-app-gleb.azurewebsites.net/health
# {"status": "healthy"}
```

---

## 13. Troubleshooting

### "No hosted parallelism has been purchased or granted"

**Проблема:** Microsoft отключила бесплатные параллельные задания для новых организаций с 2023 года.

**Решение:** Настроить self-hosted агент (см. Шаг 7) или заполнить форму на бесплатный грант: https://aka.ms/azpipelines-parallelism-request

---

### UsePythonVersion@0 не работает на self-hosted агенте

**Проблема:** `Failed to download Python from the Github Actions python registry`

**Решение:** Удали задачу `UsePythonVersion@0` из pipeline. На self-hosted агенте Python уже установлен системно. Используй напрямую:
```yaml
- script: |
    python3 -m venv .venv
    source .venv/bin/activate
```

---

### pytest exit code 4 (command line error)

**Проблема:** `--cov` флаг не найден: `error: unrecognized arguments: --cov`

**Решение:** Добавить `pytest-cov` в `requirements.txt`:
```
pytest-cov==6.1.0
```

---

### 409 Conflict при деплое на F1 тире

**Проблема:** `Operation returned an invalid status code 'Conflict'` при использовании `AzureRmWebAppDeployment@4` с zipDeploy.

**Причина:** F1 тир использует файловую систему общего хранилища. zipDeploy блокирует файлы и конфликтует при параллельных деплоях.

**Решение:** Используй `AzureCLI@2` с `az webapp deploy` вместо `AzureRmWebAppDeployment@4`:
```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: "azure-service-connection"
    scriptType: "bash"
    scriptLocation: "inlineScript"
    inlineScript: |
      az webapp deploy \
        --resource-group rg-hello-cicd \
        --name hello-cicd-app-gleb \
        --src-path "$(Pipeline.Workspace)/app-package/app-$(Build.BuildId).zip" \
        --type zip \
        --async false \
        --timeout 300
```

---

### "More than one package matched *.zip"

**Проблема:** На self-hosted агенте артефакты предыдущих сборок не удаляются автоматически.

**Решение:** Всегда включай `$(Build.BuildId)` в имя архива:
```yaml
archiveFile: "$(Build.ArtifactStagingDirectory)/app-$(Build.BuildId).zip"
```
И в путь при деплое:
```bash
--src-path "$(Pipeline.Workspace)/app-package/app-$(Build.BuildId).zip"
```

---

### Environment "staging" требует ручного Permit

**Поведение:** При первом запуске pipeline с новым Environment pipeline останавливается на `Checkpoint.Authorization` и ждёт подтверждения.

**Это ожидаемо:** Встроенный механизм защиты Azure DevOps — pipeline не может автоматически получить доступ к новому ресурсу без подтверждения оператора.

**Почему нельзя обойти через CLI:** API `PATCH pipelinePermissions/environment/{id}` требует PAT со скоупом **"Environment (Read & manage)"**. Стандартный "Full Access" PAT этот скоуп не включает — вернёт 401. Создание PAT с явным скоупом Environment решает проблему, но для учебного проекта проще нажать Permit один раз.

**Решение:** В UI: Pipelines → [текущий запуск] → "This pipeline needs permission to access a resource" → **Permit**.  
После первого разрешения повторного подтверждения не требуется.

---

## Ссылки на документацию

| Тема | Ссылка |
|---|---|
| Azure CLI installation | https://learn.microsoft.com/cli/azure/install-azure-cli |
| Azure DevOps CLI extension | https://learn.microsoft.com/azure/devops/cli/index |
| YAML schema reference | https://learn.microsoft.com/azure/devops/pipelines/yaml-schema |
| Triggers (CI/PR) | https://learn.microsoft.com/azure/devops/pipelines/build/triggers |
| Stages and jobs | https://learn.microsoft.com/azure/devops/pipelines/process/stages |
| Environments | https://learn.microsoft.com/azure/devops/pipelines/process/environments |
| Approvals and checks | https://learn.microsoft.com/azure/devops/pipelines/process/approvals |
| Self-hosted Linux agents | https://learn.microsoft.com/azure/devops/pipelines/agents/linux-agent |
| Agent pools | https://learn.microsoft.com/azure/devops/pipelines/agents/pools-queues |
| Service connections | https://learn.microsoft.com/azure/devops/pipelines/library/service-endpoints |
| AzureCLI@2 task | https://learn.microsoft.com/azure/devops/pipelines/tasks/deploy/azure-cli |
| PublishTestResults@2 | https://learn.microsoft.com/azure/devops/pipelines/tasks/test/publish-test-results |
| PublishCodeCoverageResults@2 | https://learn.microsoft.com/azure/devops/pipelines/tasks/test/publish-code-coverage-results |
| ArchiveFiles@2 | https://learn.microsoft.com/azure/devops/pipelines/tasks/utility/archive-files |
| az webapp deploy | https://learn.microsoft.com/cli/azure/webapp#az-webapp-deploy |
| App Service (Linux) | https://learn.microsoft.com/azure/app-service/overview |
| Service Principal | https://learn.microsoft.com/cli/azure/ad/sp#az-ad-sp-create-for-rbac |
| Predefined variables | https://learn.microsoft.com/azure/devops/pipelines/build/variables |
| Free parallelism request | https://aka.ms/azpipelines-parallelism-request |
| Pipeline permissions REST API | https://learn.microsoft.com/rest/api/azure/devops/approvalsandchecks/pipeline-permissions |
