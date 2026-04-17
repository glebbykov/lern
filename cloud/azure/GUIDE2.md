# Azure DevOps CI/CD: Лабораторная работа №2

**Продолжение Lab 1.** Расширяем pipeline до двухэтапного деплоя (staging → production)  
с управлением секретами через Azure Key Vault, мониторингом через Application Insights,  
хранилищем артефактов для rollback и Branch Policies.

> **Предварительное условие:** Lab 1 завершена, pipeline `hello-cicd-pipeline` работает,  
> приложение доступно на `hello-cicd-app-gleb.azurewebsites.net`.

> **Статус гайда:** весь Azure CLI-поток (Key Vault, App Insights, Storage, Web App,
> availability test, RBAC, app settings, Blob upload/download) проверен в реальной
> подписке в двух независимых экземплярах. Staging-деплой с передачей `BUILD_ID` и
> `APP_SECRET_KEY` из Key Vault подтверждён: `/version` и `/config` возвращают корректные
> значения. Azure DevOps часть (Variable Groups, Pipelines, Branch Policies) требует
> PAT и проверяется при прохождении студентом.

---

## Содержание

1. [Что добавляется в Lab 2](#1-что-добавляется-в-lab-2)
2. [Расширение приложения](#2-расширение-приложения)
3. [Azure Key Vault](#3-azure-key-vault)
4. [Application Insights](#4-application-insights)
5. [Azure Storage Account для rollback-артефактов](#5-azure-storage-account-для-rollback-артефактов)
6. [Variable Group, связанная с Key Vault](#6-variable-group-связанная-с-key-vault)
7. [Web App для production](#7-web-app-для-production)
8. [Обновлённый pipeline YAML](#8-обновлённый-pipeline-yaml)
9. [Branch Policy](#9-branch-policy)
10. [Результат](#10-результат)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Что добавляется в Lab 2

| Что | Зачем |
|---|---|
| Новые эндпоинты `/version`, `/config` | Демонстрируют передачу данных из pipeline в приложение |
| Azure Key Vault | Хранение секретов вне кода и pipeline YAML |
| Application Insights | Телеметрия запросов и availability-тест на `/health` |
| Azure Storage Account | Хранение rollback-артефакта (zip последнего удачного билда) |
| Variable Group → Key Vault | Безопасная передача секретов в pipeline без хардкода |
| Stage `CD_Production` | Второй деплой с Approval Gate после staging |
| Rollback job | Автоматический откат при ошибке деплоя в production |
| Branch Policy | Запрет мержа в main без прохождения CI-pipeline |

**Ресурсы из Lab 1, которые остаются без изменений:**

```
rg-hello-cicd              ← Resource Group (используется как есть)
plan-hello-cicd            ← App Service Plan (используется для обоих app)
hello-cicd-app-gleb        ← Staging Web App (из Lab 1)
azure-service-connection   ← Service Connection (без изменений)
self-hosted-pool           ← Agent Pool (без изменений)
```

---

## 2. Расширение приложения

### 2.1 Обновить app.py

Добавить два новых эндпоинта к существующему приложению из Lab 1:

```python
# app.py — полная версия (заменяет файл из Lab 1)
import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({"message": "Hello, Azure DevOps CI/CD!", "status": "ok"})

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/version")
def version():
    # BUILD_ID задаётся pipeline через az webapp config appsettings set
    build_id = os.environ.get("BUILD_ID", "local")
    return jsonify({"build_id": build_id, "status": "ok"})

@app.route("/config")
def config():
    # Проверяем наличие секрета, не раскрывая его значение
    secret_configured = bool(os.environ.get("APP_SECRET_KEY"))
    return jsonify({"secret_configured": secret_configured, "status": "ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

> **Почему без Application Insights SDK в коде:** инструментацию AI (`azure-monitor-opentelemetry`
> или `opencensus-ext-flask`) на Python App Service с Linux F1/B1 тиром **не рекомендуется
> импортировать в `app.py`**. Эти пакеты увеличивают cold start приложения до 40+ секунд, что
> превышает дефолтный лимит startup probe Azure App Service (230 секунд в сумме с pip install
> + container init), и приводит к exit code 3 при старте.
>
> Availability test из шага 4.2 работает как внешний ping на `/health` независимо от того,
> подключён SDK внутри приложения или нет — это первичный и самый важный сигнал наблюдаемости.
>
> **Опциональное расширение (для любознательных, только на B2+ тире):** см. подраздел 2.5 ниже.

### 2.2 Обновить requirements.txt

```
# requirements.txt — полная версия (заменяет файл из Lab 1)
flask==3.1.0
gunicorn==23.0.0
pytest==8.3.5
pytest-flask==1.3.0
pytest-cov==6.1.0
```

> **Лучшая практика:** держите приложение в requirements.txt минимальным — это ускоряет
> cold start на F1/B1 тире.

### 2.3 Обновить tests/test_app.py

```python
# tests/test_app.py — полная версия (заменяет файл из Lab 1)
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

def test_version(client):
    response = client.get("/version")
    assert response.status_code == 200
    data = response.get_json()
    assert "build_id" in data
    assert data["status"] == "ok"

def test_config(client):
    response = client.get("/config")
    assert response.status_code == 200
    data = response.get_json()
    assert "secret_configured" in data
    assert data["status"] == "ok"
```

### 2.4 Локальная проверка перед коммитом

```bash
cd hello-cicd-app

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Запустить тесты — должны пройти все 4
pytest tests/ -v

# Ожидаемый вывод:
# PASSED tests/test_app.py::test_index
# PASSED tests/test_app.py::test_health
# PASSED tests/test_app.py::test_version
# PASSED tests/test_app.py::test_config
# 4 passed
```

### 2.5 (Опционально) Application Insights SDK в приложении

Этот раздел добавляет автоматическую инструментацию HTTP-запросов через OpenTelemetry.  
**Требует минимум B2 тир** — на F1/B1 container startup превышает 230-секундный лимит.

Добавить в `requirements.txt`:
```
azure-monitor-opentelemetry==1.6.4
```

Добавить в `app.py` сразу после `app = Flask(__name__)`:
```python
_ai_connection_string = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING")
if _ai_connection_string:
    from azure.monitor.opentelemetry import configure_azure_monitor
    configure_azure_monitor(connection_string=_ai_connection_string)
```

Проверить что инициализация успешна:
```bash
curl https://hello-cicd-app-gleb.azurewebsites.net/
# Через ~2 минуты telemetry появится в Application Insights → Logs → requests
```

> **Почему не `opencensus-ext-flask`:** Старый пакет deprecated Microsoft-ом и принудительно
> даунгрейдит Flask с 3.x до 2.3.3 (его pin: `Flask<3`). Это ломает Flask 3.1.

**Документация:**
- [Azure Monitor OpenTelemetry Distro](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable?tabs=python)
- [azure-monitor-opentelemetry (PyPI)](https://pypi.org/project/azure-monitor-opentelemetry/)

---

## 3. Azure Key Vault

Key Vault — централизованное хранилище секретов. Pipeline читает секреты через Variable Group,  
не хардкодя их в YAML.

### 3.0 Регистрация Resource Providers (одноразово для подписки)

В Lab 1 Microsoft.Web зарегистрировался автоматически при создании App Service.  
В Lab 2 добавляются новые namespace — их нужно зарегистрировать один раз на подписку.

```bash
# Регистрируем все нужные провайдеры параллельно (каждый — 1-3 минуты)
az provider register --namespace Microsoft.KeyVault &
az provider register --namespace Microsoft.Insights &
az provider register --namespace Microsoft.Storage &
az provider register --namespace Microsoft.OperationalInsights &
wait

# Проверить что все перешли в Registered
for ns in Microsoft.KeyVault Microsoft.Insights Microsoft.Storage Microsoft.OperationalInsights; do
  state=$(az provider show --namespace $ns --query registrationState -o tsv)
  echo "  $ns → $state"
done

# Если видишь "Registering" — подожди 1-2 минуты и проверь снова.
# Без Registered создание ресурсов упадёт с MissingSubscriptionRegistration.
```

> **Почему это важно:** Первая попытка создать Key Vault без регистрации Microsoft.KeyVault падает:  
> `ERROR: (MissingSubscriptionRegistration) The subscription is not registered to use namespace 'Microsoft.KeyVault'`.  
> Регистрация нужна один раз на подписку — результат сохраняется между сессиями.

### 3.1 Создать Key Vault

```bash
# Переменные (согласованы с Lab 1)
RG="rg-hello-cicd"
LOCATION="westeurope"
KV_NAME="kv-hello-cicd-gleb"  # Должно быть глобально уникальным (3-24 символа)

# 1. Создать Key Vault
az keyvault create \
  --name $KV_NAME \
  --resource-group $RG \
  --location $LOCATION \
  --sku standard

# Проверить создание
az keyvault show --name $KV_NAME --query properties.vaultUri -o tsv
```

### 3.2 Дать текущему пользователю права на запись секретов

Key Vault создан с `enableRbacAuthorization=true` (дефолт для новых KV).  
Даже владелец подписки не может сразу писать секреты — нужна отдельная data-plane роль.

```bash
# Получить object ID текущего пользователя (не appId, а именно object ID)
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv)
KV_ID=$(az keyvault show --name $KV_NAME --query id -o tsv)

# Назначить роль Key Vault Secrets Officer (create/update/delete/read секретов)
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee-object-id $CURRENT_USER_ID \
  --assignee-principal-type User \
  --scope $KV_ID

# Подождать 30-60 секунд — RBAC-изменения распространяются не мгновенно.
```

> **Без этого шага** следующая команда `az keyvault secret set` падает:  
> `Code: Forbidden — ForbiddenByRbac — Action: Microsoft.KeyVault/vaults/secrets/setSecret/action`.

> **Почему User, а не Contributor:** Contributor на подписке даёт только control-plane права
> (управление самим ресурсом Key Vault). Чтение/запись секретов — это data-plane, требующая
> отдельных ролей: Key Vault Secrets Officer (запись+чтение) или Key Vault Secrets User (только чтение).

### 3.3 Добавить секреты

```bash
# 1. Добавить секрет для приложения
# В реальном проекте это был бы JWT secret, API key и т.д.
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "APP-SECRET-KEY" \
  --value "$(openssl rand -base64 32)"

# 2. Placeholder для Application Insights (заполним в шаге 4)
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "APPLICATIONINSIGHTS-CONNECTION-STRING" \
  --value "placeholder"

# Проверить список секретов
az keyvault secret list --vault-name $KV_NAME --query "[].name" -o tsv
```

### 3.4 Дать Service Principal доступ к Key Vault

Service Principal из Lab 1 (`sp-hello-cicd-pipeline`) должен читать секреты для Variable Group.

```bash
# Получить appId Service Principal
SP_APP_ID=$(az ad sp list \
  --display-name "sp-hello-cicd-pipeline" \
  --query "[0].appId" -o tsv)

echo "Service Principal appId: $SP_APP_ID"

# Назначить роль Key Vault Secrets User (только чтение секретов)
# Лучшая практика: минимальные привилегии — не Contributor, а только чтение секретов
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $SP_APP_ID \
  --scope "$(az keyvault show --name $KV_NAME --query id -o tsv)"

# Проверить
az role assignment list \
  --assignee $SP_APP_ID \
  --scope "$(az keyvault show --name $KV_NAME --query id -o tsv)" \
  --query "[].roleDefinitionName" -o tsv
```

> **Лучшая практика:** Роль `Key Vault Secrets User` позволяет только читать секреты.
> Роль `Key Vault Contributor` даёт управление самим ресурсом (создание, удаление) — для pipeline избыточно.

> **RBAC vs Access Policies:** Команда выше использует Azure RBAC (рекомендуемый способ начиная с 2021 года).
> Убедись что Key Vault создан с `--enable-rbac-authorization` (по умолчанию включено для новых KV).

**Документация:**
- [Azure Key Vault overview](https://learn.microsoft.com/azure/key-vault/general/overview)
- [az keyvault create](https://learn.microsoft.com/cli/azure/keyvault#az-keyvault-create)
- [az keyvault secret set](https://learn.microsoft.com/cli/azure/keyvault/secret#az-keyvault-secret-set)
- [Key Vault RBAC guide](https://learn.microsoft.com/azure/key-vault/general/rbac-guide)
- [Key Vault built-in roles](https://learn.microsoft.com/azure/key-vault/general/rbac-guide#azure-built-in-roles-for-key-vault-data-plane-operations)
  (Secrets Officer / Secrets User / Contributor)
- [Control plane vs data plane](https://learn.microsoft.com/azure/key-vault/general/security-features#privileged-access)
- [az ad signed-in-user show](https://learn.microsoft.com/cli/azure/ad/signed-in-user#az-ad-signed-in-user-show)
- [az role assignment create](https://learn.microsoft.com/cli/azure/role/assignment#az-role-assignment-create)
- [RBAC role propagation](https://learn.microsoft.com/azure/role-based-access-control/troubleshooting#role-assignments-with-identity-not-found)
- [Secret rotation best practices](https://learn.microsoft.com/azure/key-vault/secrets/tutorial-rotation)

---

## 4. Application Insights

Application Insights собирает телеметрию HTTP-запросов, исключений и performance-метрики.

```bash
# Установить расширение (если не установлено)
az extension add --name application-insights

RG="rg-hello-cicd"
AI_NAME="ai-hello-cicd"

# 1. Создать Application Insights ресурс
az monitor app-insights component create \
  --app $AI_NAME \
  --resource-group $RG \
  --location westeurope \
  --kind web \
  --application-type web

# 2. Получить Connection String
AI_CONNECTION_STRING=$(az monitor app-insights component show \
  --app $AI_NAME \
  --resource-group $RG \
  --query connectionString -o tsv)

echo "Connection String: $AI_CONNECTION_STRING"
```

### 4.1 Обновить секрет в Key Vault

```bash
# Заменить placeholder реальным Connection String
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "APPLICATIONINSIGHTS-CONNECTION-STRING" \
  --value "$AI_CONNECTION_STRING"

# Проверить (покажет начало значения)
az keyvault secret show \
  --vault-name $KV_NAME \
  --name "APPLICATIONINSIGHTS-CONNECTION-STRING" \
  --query "value" -o tsv | cut -c1-50
```

### 4.2 Настроить Availability Test

Availability test делает ping на `/health` каждые 5 минут из Azure-датацентров.

```bash
APP_NAME="hello-cicd-app-gleb"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Посмотреть список доступных location ID для availability test в твоём регионе
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG}/providers/Microsoft.Insights/components/${AI_NAME}/syntheticmonitorlocations?api-version=2020-02-02" \
  --query "value[].{name:DisplayName, id:Tag}" -o table

# Создать standard availability test (ping на /health каждые 5 мин)
# ВАЖНО: флаг --locations требует формат "Id=XXX", а не JSON.
# ВАЖНО: флаг называется --web-test-kind (не --defined-web-test-kind).
# ВАЖНО: для привязки теста к AI-компоненту нужен tag hidden-link:{AI_RESOURCE_ID}=Resource
az monitor app-insights web-test create \
  --resource-group $RG \
  --name "health-check-staging" \
  --location westeurope \
  --web-test-kind standard \
  --defined-web-test-name "health-check-staging" \
  --synthetic-monitor-id "health-check-staging" \
  --enabled true \
  --frequency 300 \
  --timeout 30 \
  --retry-enabled true \
  --expected-status-code 200 \
  --request-url "https://${APP_NAME}.azurewebsites.net/health" \
  --locations Id="emea-nl-ams-azr" \
  --locations Id="emea-gb-db3-azr" \
  --locations Id="emea-fr-pra-edge" \
  --tags hidden-link:"/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG}/providers/microsoft.insights/components/${AI_NAME}"=Resource
```

> **Лучшая практика:** Используй минимум 3 локации для availability test — это позволяет отличить
> проблему приложения от сбоя в одном датацентре Azure.

> **Актуальные location IDs** (получи через `syntheticmonitorlocations` API выше):
> `emea-nl-ams-azr` (West Europe), `emea-gb-db3-azr` (North Europe),
> `emea-fr-pra-edge` (France Central), `us-va-ash-azr` (East US),
> `apac-sg-sin-azr` (Southeast Asia). **Старые `-azr` locations типа `emea-fr-pra-azr`
> больше не поддерживаются** — API вернёт `BadRequest: ... is not a supported location`.

**Документация:**
- [Application Insights overview](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Application Insights для Python](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable?tabs=python)
- [az monitor app-insights component create](https://learn.microsoft.com/cli/azure/monitor/app-insights/component#az-monitor-app-insights-component-create)
- [az monitor app-insights web-test create](https://learn.microsoft.com/cli/azure/monitor/app-insights/web-test#az-monitor-app-insights-web-test-create)
- [Availability tests overview](https://learn.microsoft.com/azure/azure-monitor/app/availability-overview)
- [Standard availability tests](https://learn.microsoft.com/azure/azure-monitor/app/availability-standard-tests)
- [WebTests REST API (syntheticmonitorlocations)](https://learn.microsoft.com/rest/api/application-insights/web-tests)
- [Workspace-based AI (next gen)](https://learn.microsoft.com/azure/azure-monitor/app/create-workspace-resource)

---

## 5. Azure Storage Account для rollback-артефактов

Pipeline сохраняет zip последнего удачного деплоя в Blob Storage.  
При ошибке в production — откатывается к этому архиву.

```bash
RG="rg-hello-cicd"
# Имя Storage Account: 3-24 символа, только строчные буквы и цифры, глобально уникальное
SA_NAME="hellocicdgleb"  # Замени на своё уникальное имя

# 1. Создать Storage Account
az storage account create \
  --name $SA_NAME \
  --resource-group $RG \
  --location westeurope \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2

# 2. Дать ТЕКУЩЕМУ пользователю роль Storage Blob Data Contributor
# (без неё `az storage container create --auth-mode login` упадёт с 403)
SA_ID=$(az storage account show --name $SA_NAME --resource-group $RG --query id -o tsv)
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv)

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee-object-id $CURRENT_USER_ID \
  --assignee-principal-type User \
  --scope $SA_ID

# Подожди 30-60 секунд — RBAC распространяется не мгновенно.

# 3. Создать контейнер для артефактов
az storage container create \
  --account-name $SA_NAME \
  --name "artifacts" \
  --auth-mode login

# 4. Дать Service Principal (для pipeline) права на Blob Storage
SP_APP_ID=$(az ad sp list \
  --display-name "sp-hello-cicd-pipeline" \
  --query "[0].appId" -o tsv)

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $SP_APP_ID \
  --scope $SA_ID

# Проверить контейнер
az storage container show \
  --account-name $SA_NAME \
  --name "artifacts" \
  --auth-mode login \
  --query name -o tsv
```

> **Лучшая практика:** Роль `Storage Blob Data Contributor` на уровне конкретного Storage Account —
> не на всю подписку и не `Storage Account Contributor` (который даёт управление ресурсом, а не данными).

> **Почему не хранить артефакт только в DevOps:** Pipeline Artifacts удаляются через retention policy
> (по умолчанию 30 дней). Blob Storage позволяет хранить неограниченно и читать без PAT.

**Документация:**
- [Azure Blob Storage overview](https://learn.microsoft.com/azure/storage/blobs/storage-blobs-overview)
- [az storage account create](https://learn.microsoft.com/cli/azure/storage/account#az-storage-account-create)
- [az storage container create](https://learn.microsoft.com/cli/azure/storage/container#az-storage-container-create)
- [Storage Blob Data roles](https://learn.microsoft.com/azure/storage/blobs/assign-azure-role-data-access)
- [Authorize with Microsoft Entra (auth-mode login)](https://learn.microsoft.com/azure/storage/blobs/authorize-data-operations-cli)
- [Storage redundancy (LRS/ZRS/GRS)](https://learn.microsoft.com/azure/storage/common/storage-redundancy)
- [Pipeline Artifacts retention](https://learn.microsoft.com/azure/devops/pipelines/artifacts/artifacts-overview#retention)

---

## 6. Variable Group, связанная с Key Vault

Variable Group — это именованный набор переменных в Azure DevOps Library, доступный pipeline.  
Линковка с Key Vault позволяет читать секреты без хардкода в YAML.

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
KV_NAME="kv-hello-cicd-gleb"

# Создать Variable Group, связанную с Key Vault
az pipelines variable-group create \
  --name "kv-secrets" \
  --authorize true \
  --variables placeholder="dummy" \
  --output json

# Получить ID созданной группы
VG_ID=$(az pipelines variable-group list \
  --query "[?name=='kv-secrets'].id" -o tsv)

echo "Variable Group ID: $VG_ID"
```

### 6.1 Привязать Key Vault к Variable Group через UI

Линковка Variable Group к Key Vault выполняется в DevOps UI (REST API для этого требует больше шагов):

```
Azure DevOps → Pipelines → Library → kv-secrets → Edit
  → Link secrets from an Azure key vault as variables
  → Azure subscription: выбрать azure-service-connection
  → Key vault name: kv-hello-cicd-gleb
  → + Add → выбрать оба секрета:
      ✓ APP-SECRET-KEY
      ✓ APPLICATIONINSIGHTS-CONNECTION-STRING
  → Save
```

После этого удалить placeholder-переменную:

```bash
az pipelines variable-group variable delete \
  --group-id $VG_ID \
  --name "placeholder"
```

### 6.2 Проверить содержимое Variable Group

```bash
# Проверить что секреты появились в группе
az pipelines variable-group show \
  --group-id $VG_ID \
  --query "variables" \
  --output table
```

> **Лучшая практика:** Variable Group с секретами из KV — переменные в pipeline доступны как
> `$(APP-SECRET-KEY)`. Их значения маскируются в логах автоматически.

> **ВАЖНО:** После сохранения секретов pipeline автоматически получит их значения на момент запуска.
> Ротация секрета в Key Vault → следующий запуск pipeline подхватит новое значение без изменений в YAML.

**Документация:**
- [Library & variable groups overview](https://learn.microsoft.com/azure/devops/pipelines/library)
- [Variable groups в YAML](https://learn.microsoft.com/azure/devops/pipelines/library/variable-groups)
- [Link secrets from Azure Key Vault](https://learn.microsoft.com/azure/devops/pipelines/library/variable-groups#link-secrets-from-an-azure-key-vault)
- [az pipelines variable-group create](https://learn.microsoft.com/cli/azure/pipelines/variable-group#az-pipelines-variable-group-create)
- [az pipelines variable-group variable delete](https://learn.microsoft.com/cli/azure/pipelines/variable-group/variable#az-pipelines-variable-group-variable-delete)
- [Secret variables & logs masking](https://learn.microsoft.com/azure/devops/pipelines/process/variables#secret-variables)

---

## 7. Web App для production

```bash
RG="rg-hello-cicd"
APP_PLAN="plan-hello-cicd"
PROD_APP_NAME="hello-cicd-app-gleb-prod"  # Глобально уникальное имя

# 1. Создать Web App для production на том же App Service Plan
az webapp create \
  --name $PROD_APP_NAME \
  --resource-group $RG \
  --plan $APP_PLAN \
  --runtime "PYTHON:3.11"

# 2. Настроить startup command (идентично staging из Lab 1)
az webapp config set \
  --name $PROD_APP_NAME \
  --resource-group $RG \
  --startup-file "gunicorn --bind=0.0.0.0:8000 app:app"

# 3. ВАЖНО: включить установку зависимостей при деплое.
# Без SCM_DO_BUILD_DURING_DEPLOYMENT=true Azure не запускает pip install для zip-деплоя,
# и приложение падает с exit code 3 (gunicorn worker failed to boot — ModuleNotFoundError).
az webapp config appsettings set \
  --name $PROD_APP_NAME \
  --resource-group $RG \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true

# Применить тот же setting к staging (если не был установлен в Lab 1)
az webapp config appsettings set \
  --name hello-cicd-app-gleb \
  --resource-group $RG \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true

# 4. Проверить что приложение доступно
az webapp show \
  --name $PROD_APP_NAME \
  --resource-group $RG \
  --query defaultHostName -o tsv
```

> **Почему SCM_DO_BUILD_DURING_DEPLOYMENT=true:** `az webapp deploy --type zip` по умолчанию
> просто распаковывает zip и запускает startup-command. Если в zip нет `.venv/`, gunicorn
> падает с `ModuleNotFoundError: flask`. С этим setting App Service запускает
> Oryx build: `pip install -r requirements.txt` перед стартом контейнера.

> **Лучшая практика:** Оба приложения (staging + production) живут на одном App Service Plan `plan-hello-cicd`.
> F1 тир поддерживает несколько приложений на одном плане. В production-проектах staging и production
> изолируются на разных планах.

> **⚠ ВАЖНО: F1 тир и квота CPU.** F1 плана выделяет **60 CPU-минут в день на ВЕСЬ план**, а не на приложение.
> Два app-а (staging + production) делят этот бюджет. При активной разработке (несколько деплоев +
> availability test каждые 5 минут + локальные curl-запросы) квота исчерпывается за 1-2 часа и app
> переходит в состояние `QuotaExceeded` до полуночи UTC.
> Проверить: `az webapp show --name ... --query state` → если `QuotaExceeded`, нужно либо ждать сброса,
> либо апгрейдиться до Basic B1 (`az appservice plan update --sku B1 --name plan-hello-cicd -g rg-hello-cicd`).

**Документация:**
- [az webapp create](https://learn.microsoft.com/cli/azure/webapp#az-webapp-create)
- [az webapp config set](https://learn.microsoft.com/cli/azure/webapp/config#az-webapp-config-set)
- [Multiple apps on one plan](https://learn.microsoft.com/azure/app-service/overview-hosting-plans#multiple-apps-in-the-same-app-service-plan)
- [App Service configure Python](https://learn.microsoft.com/azure/app-service/configure-language-python)
- [F1/B1/Standard tier sizing](https://learn.microsoft.com/azure/app-service/overview-hosting-plans#apps-and-app-service-plans)
- [az appservice plan update (scaling)](https://learn.microsoft.com/cli/azure/appservice/plan#az-appservice-plan-update)

---

## 8. Обновлённый pipeline YAML

Полная замена `azure-pipelines.yml`. Изменения относительно Lab 1 отмечены в комментариях.

```yaml
# azure-pipelines.yml

# ─── ТРИГГЕРЫ (без изменений относительно Lab 1) ─────────────────────────────
trigger:
  branches:
    include:
      - main
  paths:
    exclude:
      - "*.md"

pr:
  branches:
    include:
      - main

# ─── ПЕРЕМЕННЫЕ ──────────────────────────────────────────────────────────────
# НОВОЕ: подключаем Variable Group с секретами из Key Vault
variables:
  - group: kv-secrets                        # → APP-SECRET-KEY, APPLICATIONINSIGHTS-CONNECTION-STRING

  - name: pythonVersion
    value: "3.11"
  - name: stagingAppName
    value: "hello-cicd-app-gleb"             # из Lab 1
  - name: productionAppName
    value: "hello-cicd-app-gleb-prod"        # НОВОЕ
  - name: resourceGroup
    value: "rg-hello-cicd"                   # из Lab 1
  - name: storageAccount
    value: "hellocicdgleb"                   # НОВОЕ: замени на своё имя из шага 5
  - name: storageContainer
    value: "artifacts"                       # НОВОЕ

# ─── STAGES ──────────────────────────────────────────────────────────────────
stages:

# ── STAGE 1: CI (без изменений относительно Lab 1) ───────────────────────────
  - stage: CI
    displayName: "Build & Test"
    jobs:
      - job: build_and_test
        displayName: "Install & Test"
        pool:
          name: "self-hosted-pool"

        steps:
          - script: |
              python3 -m venv .venv
              source .venv/bin/activate
              python3 -m pip install --upgrade pip
              pip install -r requirements.txt
            displayName: "Create venv & install dependencies"

          - script: |
              source .venv/bin/activate
              mkdir -p junit
              pytest tests/ \
                --junitxml=junit/test-results.xml \
                --cov=. \
                --cov-report=xml:coverage.xml \
                -v
            displayName: "Run tests with coverage"

          - task: PublishTestResults@2
            displayName: "Publish test results"
            condition: succeededOrFailed()
            inputs:
              testResultsFormat: "JUnit"
              testResultsFiles: "junit/test-results.xml"
              failTaskOnFailedTests: true

          - task: PublishCodeCoverageResults@2
            displayName: "Publish code coverage"
            condition: succeededOrFailed()
            inputs:
              codeCoverageTool: "Cobertura"
              summaryFileLocation: "coverage.xml"

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

          - task: PublishBuildArtifacts@1
            displayName: "Publish artifact"
            inputs:
              PathtoPublish: "$(Build.ArtifactStagingDirectory)"
              ArtifactName: "app-package"
              publishLocation: "Container"

# ── STAGE 2: CD Staging ───────────────────────────────────────────────────────
# ИЗМЕНЕНО: переименован из "CD" в "CD_Staging", добавлена конфигурация app settings,
# добавлено сохранение rollback-артефакта в Blob Storage
  - stage: CD_Staging
    displayName: "Deploy to Staging"
    dependsOn: CI
    condition: |
      and(
        succeeded(),
        eq(variables['Build.SourceBranch'], 'refs/heads/main')
      )
    jobs:
      - deployment: deploy_staging
        displayName: "Deploy to Staging App Service"
        environment: "staging"
        pool:
          name: "self-hosted-pool"
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: app-package
                  displayName: "Download artifact"

                # НОВОЕ: передаём BUILD_ID и секреты как app settings
                # Секреты читаются из Variable Group (значения маскируются в логах)
                - task: AzureCLI@2
                  displayName: "Configure app settings (staging)"
                  inputs:
                    azureSubscription: "azure-service-connection"
                    scriptType: "bash"
                    scriptLocation: "inlineScript"
                    inlineScript: |
                      az webapp config appsettings set \
                        --resource-group $(resourceGroup) \
                        --name $(stagingAppName) \
                        --settings \
                          BUILD_ID="$(Build.BuildId)" \
                          APP_SECRET_KEY="$(APP-SECRET-KEY)" \
                          APPLICATIONINSIGHTS_CONNECTION_STRING="$(APPLICATIONINSIGHTS-CONNECTION-STRING)"

                - task: AzureCLI@2
                  displayName: "Deploy to Staging"
                  inputs:
                    azureSubscription: "azure-service-connection"
                    scriptType: "bash"
                    scriptLocation: "inlineScript"
                    inlineScript: |
                      az webapp deploy \
                        --resource-group $(resourceGroup) \
                        --name $(stagingAppName) \
                        --src-path "$(Pipeline.Workspace)/app-package/app-$(Build.BuildId).zip" \
                        --type zip \
                        --async false \
                        --timeout 600

                # НОВОЕ: сохраняем артефакт как rollback.zip (перезаписываем при каждом удачном деплое)
                - task: AzureCLI@2
                  displayName: "Save rollback artifact to Blob Storage"
                  inputs:
                    azureSubscription: "azure-service-connection"
                    scriptType: "bash"
                    scriptLocation: "inlineScript"
                    inlineScript: |
                      az storage blob upload \
                        --account-name $(storageAccount) \
                        --container-name $(storageContainer) \
                        --name "rollback.zip" \
                        --file "$(Pipeline.Workspace)/app-package/app-$(Build.BuildId).zip" \
                        --overwrite true \
                        --auth-mode login
                      echo "Rollback artifact saved: BuildId=$(Build.BuildId)"

# ── STAGE 3: CD Production ────────────────────────────────────────────────────
# НОВОЕ: деплой в production с Approval Gate и автоматическим rollback при ошибке
  - stage: CD_Production
    displayName: "Deploy to Production"
    dependsOn: CD_Staging
    condition: |
      and(
        succeeded(),
        eq(variables['Build.SourceBranch'], 'refs/heads/main')
      )
    jobs:
      - deployment: deploy_production
        displayName: "Deploy to Production App Service"
        environment: "production"          # Approval Gate настраивается на этом environment
        pool:
          name: "self-hosted-pool"
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: app-package
                  displayName: "Download artifact"

                - task: AzureCLI@2
                  displayName: "Configure app settings (production)"
                  inputs:
                    azureSubscription: "azure-service-connection"
                    scriptType: "bash"
                    scriptLocation: "inlineScript"
                    inlineScript: |
                      az webapp config appsettings set \
                        --resource-group $(resourceGroup) \
                        --name $(productionAppName) \
                        --settings \
                          BUILD_ID="$(Build.BuildId)" \
                          APP_SECRET_KEY="$(APP-SECRET-KEY)" \
                          APPLICATIONINSIGHTS_CONNECTION_STRING="$(APPLICATIONINSIGHTS-CONNECTION-STRING)"

                - task: AzureCLI@2
                  displayName: "Deploy to Production"
                  inputs:
                    azureSubscription: "azure-service-connection"
                    scriptType: "bash"
                    scriptLocation: "inlineScript"
                    inlineScript: |
                      az webapp deploy \
                        --resource-group $(resourceGroup) \
                        --name $(productionAppName) \
                        --src-path "$(Pipeline.Workspace)/app-package/app-$(Build.BuildId).zip" \
                        --type zip \
                        --async false \
                        --timeout 600

            # НОВОЕ: rollback при ошибке деплоя
            on:
              failure:
                steps:
                  - task: AzureCLI@2
                    displayName: "Rollback production from Blob Storage"
                    inputs:
                      azureSubscription: "azure-service-connection"
                      scriptType: "bash"
                      scriptLocation: "inlineScript"
                      inlineScript: |
                        echo "Deploy failed — downloading last known good artifact..."

                        az storage blob download \
                          --account-name $(storageAccount) \
                          --container-name $(storageContainer) \
                          --name "rollback.zip" \
                          --file "/tmp/rollback-$(Build.BuildId).zip" \
                          --auth-mode login

                        echo "Redeploying last known good build to production..."
                        az webapp deploy \
                          --resource-group $(resourceGroup) \
                          --name $(productionAppName) \
                          --src-path "/tmp/rollback-$(Build.BuildId).zip" \
                          --type zip \
                          --async false \
                          --timeout 600

                        rm -f "/tmp/rollback-$(Build.BuildId).zip"
                        echo "##[warning]Rollback completed. Verify production manually."
```

### 8.1 Переименование stage "CD" → "CD_Staging"

В Lab 1 stage назывался `CD`. Теперь он называется `CD_Staging`. Azure DevOps хранит историю  
по именам stage — переименование не ломает pipeline, но сбросит историю деплоев этого stage.

### 8.2 Закоммитить изменения

```bash
# Файлы которые изменились
git add app.py requirements.txt tests/test_app.py azure-pipelines.yml

git commit -m "feat: add version/config endpoints, Key Vault secrets, Application Insights, production stage"
git push origin main
```

> **ВАЖНО:** После пуша pipeline запустится автоматически. Первый запуск с `CD_Production`
> остановится на `Checkpoint.Authorization` для нового environment `production` — нужно нажать
> **Permit** в UI (однократно, аналогично staging в Lab 1).

**Документация:**
- [Variable group в YAML](https://learn.microsoft.com/azure/devops/pipelines/library/variable-groups#use-a-variable-group)
- [Deployment job with on-failure](https://learn.microsoft.com/azure/devops/pipelines/process/deployment-jobs)
- [runOnce strategy](https://learn.microsoft.com/azure/devops/pipelines/process/deployment-jobs#runonce-deployment-strategy)
- [Deployment hooks (preDeploy/deploy/routeTraffic/postRouteTraffic/on)](https://learn.microsoft.com/azure/devops/pipelines/process/deployment-jobs#descriptions-of-life-cycle-hooks)
- [stages.dependsOn](https://learn.microsoft.com/azure/devops/pipelines/process/stages#specify-dependencies)
- [Conditions syntax (succeeded, eq, and)](https://learn.microsoft.com/azure/devops/pipelines/process/conditions)
- [az webapp config appsettings set](https://learn.microsoft.com/cli/azure/webapp/config/appsettings#az-webapp-config-appsettings-set)
- [az webapp deploy](https://learn.microsoft.com/cli/azure/webapp#az-webapp-deploy)
- [az storage blob upload](https://learn.microsoft.com/cli/azure/storage/blob#az-storage-blob-upload)
- [az storage blob download](https://learn.microsoft.com/cli/azure/storage/blob#az-storage-blob-download)
- [Pipeline.Workspace + predefined variables](https://learn.microsoft.com/azure/devops/pipelines/build/variables#pipeline-workspace)

---

## 9. Branch Policy

Branch Policy запрещает мерж в `main` без прохождения CI-pipeline.  
Это гарантирует что код с падающими тестами не попадёт в основную ветку.

```bash
# Получить ID репозитория
REPO_ID=$(az repos show \
  --repository "hello-cicd-app" \
  --query id -o tsv)

echo "Repository ID: $REPO_ID"

# Получить ID pipeline
PIPELINE_DEF_ID=$(az pipelines show \
  --name "hello-cicd-pipeline" \
  --query id -o tsv)

echo "Pipeline definition ID: $PIPELINE_DEF_ID"
```

### 9.1 Build Validation Policy

Запускает CI-pipeline при создании PR и блокирует мерж до его прохождения.

```bash
# Создать Build Validation policy на ветке main
# ВАЖНО: флаги называются --blocking и --enabled (без is-), как и --display-name — обязателен
az repos policy build create \
  --branch "main" \
  --build-definition-id $PIPELINE_DEF_ID \
  --display-name "CI build validation" \
  --blocking true \
  --enabled true \
  --queue-on-source-update-only true \
  --manual-queue-only false \
  --valid-duration 720 \
  --repository-id $REPO_ID

# Проверить созданную политику
az repos policy list \
  --repository-id $REPO_ID \
  --branch "main" \
  --output table
```

### 9.2 Minimum Reviewers Policy

Требует хотя бы одного ревьювера перед мержем (рекомендуется для командных проектов).

```bash
az repos policy approver-count create \
  --branch "main" \
  --blocking true \
  --enabled true \
  --minimum-approver-count 1 \
  --allow-downvotes false \
  --creator-vote-counts false \
  --reset-on-source-push false \
  --repository-id $REPO_ID
```

### 9.3 Проверить Branch Policy

```bash
# 1. Создать feature-ветку
git checkout -b feature/test-branch-policy
git commit --allow-empty -m "test: verify branch policy"
git push origin feature/test-branch-policy

# 2. Создать PR через CLI
az repos pr create \
  --title "test: branch policy verification" \
  --source-branch "feature/test-branch-policy" \
  --target-branch "main" \
  --description "Проверяем что CI запускается автоматически при создании PR"

# 3. Посмотреть статус PR
az repos pr list --status active --output table
```

После создания PR в DevOps UI должен появиться статус:
```
Required check: hello-cicd-pipeline — Running...
```

Мерж кнопка будет заблокирована до прохождения CI.

> **Лучшая практика:** `--valid-duration 720` означает что результат старше 720 минут (12 часов)
> считается устаревшим — требуется перезапуск pipeline. Это предотвращает мерж кода
> с давно пройденными тестами после значительных изменений в target-ветке.

**Документация:**
- [Branch policies](https://learn.microsoft.com/azure/devops/repos/git/branch-policies)
- [Build validation policy](https://learn.microsoft.com/azure/devops/repos/git/branch-policies#build-validation)
- [Require a minimum number of reviewers](https://learn.microsoft.com/azure/devops/repos/git/branch-policies#require-a-minimum-number-of-reviewers)
- [az repos policy build create](https://learn.microsoft.com/cli/azure/repos/policy/build#az-repos-policy-build-create)
- [az repos policy approver-count create](https://learn.microsoft.com/cli/azure/repos/policy/approver-count#az-repos-policy-approver-count-create)
- [az repos pr create](https://learn.microsoft.com/cli/azure/repos/pr#az-repos-pr-create)
- [az repos policy list](https://learn.microsoft.com/cli/azure/repos/policy#az-repos-policy-list)
- [Policy configurations REST API](https://learn.microsoft.com/rest/api/azure/devops/policy/configurations)

---

## 9.4 Approval Gate на production environment

```
Azure DevOps → Pipelines → Environments → production → "..." → Approvals and checks
  → + Add → Approvals
  → Approvers: [твой аккаунт]
  → Instructions: "Verify staging is healthy before approving production deploy"
  → Save
```

После этого каждый деплой в production будет останавливаться и ждать ручного подтверждения.

**Документация:**
- [Approvals and checks overview](https://learn.microsoft.com/azure/devops/pipelines/process/approvals)
- [Manual validation approval](https://learn.microsoft.com/azure/devops/pipelines/process/approvals#approvals)
- [Environment security](https://learn.microsoft.com/azure/devops/pipelines/process/environments#security)
- [Checks reference (exclusive lock, business hours, invoke REST API)](https://learn.microsoft.com/azure/devops/pipelines/process/approvals#checks)

---

## 10. Результат

После выполнения всех шагов pipeline работает по следующей схеме:

```
git push origin main
       │
       ▼
┌─────────────┐
│  CI Stage   │
│  ─────────  │
│  venv + pip │
│  pytest ✓   │  ← 4 теста (включая /version и /config)
│  coverage   │
│  zip архив  │
└──────┬──────┘
       │ succeeded() + branch == main
       ▼
┌──────────────────┐
│  CD_Staging      │
│  ──────────────  │
│  app settings:   │
│  BUILD_ID        │  ← из pipeline
│  APP_SECRET_KEY  │  ← из Key Vault
│  APPINSIGHTS_CS  │  ← из Key Vault
│  az webapp       │
│  deploy ✓        │
│  rollback.zip →  │  ← сохраняется в Blob Storage
│  Blob Storage    │
└──────┬───────────┘
       │ succeeded() + branch == main
       ▼
  [Approval Gate]   ← ручное подтверждение в DevOps UI
       │
       ▼
┌──────────────────┐
│  CD_Production   │
│  ──────────────  │
│  app settings ✓  │
│  az webapp       │
│  deploy ✓        │
│                  │
│  При ошибке:     │
│  ← rollback.zip  │  ← скачивается из Blob Storage
│  redeploy ✓      │
└──────┬───────────┘
       │
       ▼
https://hello-cicd-app-gleb.azurewebsites.net       (staging)
https://hello-cicd-app-gleb-prod.azurewebsites.net  (production)
```

### Проверить результат

```bash
STAGING="https://hello-cicd-app-gleb.azurewebsites.net"
PROD="https://hello-cicd-app-gleb-prod.azurewebsites.net"

# Staging
curl $STAGING/
# {"message": "Hello, Azure DevOps CI/CD!", "status": "ok"}

curl $STAGING/health
# {"status": "healthy"}

curl $STAGING/version
# {"build_id": "123", "status": "ok"}   ← реальный BuildId из pipeline

curl $STAGING/config
# {"secret_configured": true, "status": "ok"}   ← true = секрет из Key Vault передан

# Production (после approve)
curl $PROD/version
# {"build_id": "123", "status": "ok"}

# Проверить Application Insights (через минуту после запросов)
az monitor app-insights events show \
  --app $AI_NAME \
  --resource-group $RG \
  --type requests \
  --output table
```

---

## 11. Troubleshooting

### Variable Group не передаёт секреты: "APP-SECRET-KEY is not defined"

**Причина:** Variable Group не авторизована для pipeline или KV-линковка не сохранена.

**Решение:**
```bash
# Проверить авторизацию Variable Group
VG_ID=$(az pipelines variable-group list \
  --query "[?name=='kv-secrets'].id" -o tsv)

# Авторизовать для всех pipeline
az pipelines variable-group update \
  --group-id $VG_ID \
  --authorize true
```
Также проверь в Library → kv-secrets → Permissions → Pipeline permissions → Allow all pipelines.

---

### "Failed to get secrets from key vault" при запуске pipeline

**Причина:** Service Principal не имеет прав на чтение секретов из Key Vault.

**Диагностика:**
```bash
SP_APP_ID=$(az ad sp list --display-name "sp-hello-cicd-pipeline" --query "[0].appId" -o tsv)

az role assignment list \
  --assignee $SP_APP_ID \
  --scope "$(az keyvault show --name $KV_NAME --query id -o tsv)" \
  --query "[].roleDefinitionName" -o tsv
```

**Решение:** если вывод пустой — выполнить шаг 3.2 заново.

---

### "AuthorizationFailed" при `az storage blob upload`

**Причина:** Service Principal не имеет роли `Storage Blob Data Contributor` на Storage Account.

**Диагностика:**
```bash
SP_APP_ID=$(az ad sp list --display-name "sp-hello-cicd-pipeline" --query "[0].appId" -o tsv)
SA_ID=$(az storage account show --name $SA_NAME --resource-group $RG --query id -o tsv)

az role assignment list --assignee $SP_APP_ID --scope $SA_ID --query "[].roleDefinitionName" -o tsv
```

**Решение:** если вывод пустой — выполнить шаг 5 (блок role assignment) заново.

---

### Container exit code 3 / "Container did not start within 230s"

**Причина:** приложение не успевает инициализироваться за 230 секунд (лимит startup probe).
Основные виновники:
1. В `requirements.txt` включён `azure-monitor-opentelemetry` или `opencensus-ext-flask` —
   импорт этих пакетов делает cold start 40+ секунд.
2. Не установлен `SCM_DO_BUILD_DURING_DEPLOYMENT=true` — Azure не запускает `pip install`
   после zip-деплоя, и gunicorn падает с `ModuleNotFoundError: flask`.

**Решение 1:** Убрать OpenTelemetry из кода и requirements. Availability test из шага 4.2
всё равно даёт внешний мониторинг `/health` без инструментации.

**Решение 2:** Если нужна инструментация — см. раздел 2.5 и апгрейдиться на B2+ с увеличенным
`WEBSITES_CONTAINER_START_TIME_LIMIT`:
```bash
az webapp config appsettings set \
  --resource-group rg-hello-cicd \
  --name hello-cicd-app-gleb \
  --settings WEBSITES_CONTAINER_START_TIME_LIMIT=600
```

**Диагностика:**
```bash
az webapp log download --name hello-cicd-app-gleb --resource-group rg-hello-cicd --log-file /tmp/logs.zip
unzip -o /tmp/logs.zip -d /tmp/logs
grep -E "exit code|Traceback|Error" /tmp/logs/LogFiles/*docker*.log | tail -20
```

---

### Timeout while tracking deployment (az webapp deploy --timeout)

**Поведение:** `az webapp deploy --timeout 300` возвращает ошибку "Timeout reached while tracking
deployment status, however, the deployment operation is still on-going" — но деплой сам продолжается.

**Причина:** `SCM_DO_BUILD_DURING_DEPLOYMENT=true` запускает Oryx build (pip install всех зависимостей)
который на F1/B1 может занимать 4-6 минут.

**Решение:** Увеличить `--timeout` до `600` (10 минут):
```yaml
inlineScript: |
  az webapp deploy \
    --resource-group $(resourceGroup) \
    --name $(stagingAppName) \
    --src-path "..." \
    --type zip \
    --async false \
    --timeout 600
```

---

### pip ставит Flask 2.3.3 вместо 3.1.0

**Причина:** Устаревший пакет `opencensus-ext-flask` имеет pin `Flask<3` — его нет в Lab 2,
но если скопировать requirements из старого проекта, pip молча даунгрейднет Flask.

**Решение:** Не добавлять `opencensus-ext-flask` и `opencensus-ext-azure` в `requirements.txt`.
Для инструментации использовать `azure-monitor-opentelemetry==1.6.4` (раздел 2.5).

---

### Pipeline останавливается на "Waiting for approval" в CD_Production

**Это ожидаемо.** Approval Gate на environment `production` требует ручного подтверждения.

```
Pipelines → [текущий запуск] → CD_Production → "Review" → Approve
```

---

### Rollback скачивает старый zip, если staging деплой упал до сохранения в Blob

**Поведение:** `rollback.zip` в Blob Storage — это zip последнего **успешно задеплоенного** в staging билда.
Если текущий staging-деплой упал до шага "Save rollback artifact", в Blob лежит предыдущий успешный билд.
При rollback в production будет развёрнут именно он — это корректное поведение.

**Крайний случай:** если staging ни разу не деплоился успешно — `rollback.zip` не существует,
и шаг rollback упадёт с ошибкой. Это нормально для первого запуска.

---

### Приложение отвечает 403 "Site Disabled" после нескольких деплоев

**Причина:** F1 тир превысил дневную квоту CPU (60 минут/день на ВЕСЬ App Service Plan,
не на одно приложение). Два приложения (staging + production) делят этот бюджет.
Availability test каждые 5 минут ускоряет выработку квоты.

**Диагностика:**
```bash
az webapp show --name hello-cicd-app-gleb --resource-group rg-hello-cicd \
  --query "{state:state, usageState:usageState}" -o json
# state = "QuotaExceeded" → квота исчерпана
```

**Решение 1 (бесплатно):** Ждать сброса квоты в полночь UTC.

**Решение 2 (рекомендуется для лабораторной):** Апгрейдиться до Basic B1 (≈10 EUR/мес, без лимита CPU):
```bash
az appservice plan update \
  --name plan-hello-cicd \
  --resource-group rg-hello-cicd \
  --sku B1
```

**Решение 3:** Разнести staging и production на разные планы (B1 для production, F1 для staging).

---

### az repos policy build create: "TF400898: An Internal Error Occurred"

**Причина:** `--build-definition-id` содержит неверный ID.

**Диагностика:**
```bash
az pipelines list --output table
# Убедиться что ID правильный
```

---

## Ссылки на документацию

### Azure ресурсы (Azure CLI)
| Тема | Ссылка |
|---|---|
| Resource providers | https://learn.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types |
| az provider register | https://learn.microsoft.com/cli/azure/provider#az-provider-register |
| Azure Key Vault | https://learn.microsoft.com/azure/key-vault/general/overview |
| Key Vault RBAC guide | https://learn.microsoft.com/azure/key-vault/general/rbac-guide |
| Key Vault built-in roles | https://learn.microsoft.com/azure/key-vault/general/rbac-guide#azure-built-in-roles-for-key-vault-data-plane-operations |
| az keyvault secret set | https://learn.microsoft.com/cli/azure/keyvault/secret#az-keyvault-secret-set |
| Application Insights overview | https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview |
| AI для Python (OpenTelemetry) | https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable?tabs=python |
| azure-monitor-opentelemetry (PyPI) | https://pypi.org/project/azure-monitor-opentelemetry/ |
| Availability tests | https://learn.microsoft.com/azure/azure-monitor/app/availability-overview |
| Standard availability tests | https://learn.microsoft.com/azure/azure-monitor/app/availability-standard-tests |
| az monitor app-insights | https://learn.microsoft.com/cli/azure/monitor/app-insights |
| Azure Blob Storage | https://learn.microsoft.com/azure/storage/blobs/storage-blobs-overview |
| Storage Blob Data roles | https://learn.microsoft.com/azure/storage/blobs/assign-azure-role-data-access |
| az storage account create | https://learn.microsoft.com/cli/azure/storage/account#az-storage-account-create |
| az storage blob upload | https://learn.microsoft.com/cli/azure/storage/blob#az-storage-blob-upload |
| az storage blob download | https://learn.microsoft.com/cli/azure/storage/blob#az-storage-blob-download |
| Azure RBAC built-in roles | https://learn.microsoft.com/azure/role-based-access-control/built-in-roles |
| az role assignment create | https://learn.microsoft.com/cli/azure/role/assignment#az-role-assignment-create |
| Least privilege best practices | https://learn.microsoft.com/azure/role-based-access-control/best-practices |
| App Service Python configure | https://learn.microsoft.com/azure/app-service/configure-language-python |
| SCM_DO_BUILD_DURING_DEPLOYMENT | https://github.com/microsoft/Oryx/blob/main/doc/configuration.md |
| az webapp deploy | https://learn.microsoft.com/cli/azure/webapp#az-webapp-deploy |
| az webapp config appsettings set | https://learn.microsoft.com/cli/azure/webapp/config/appsettings#az-webapp-config-appsettings-set |

### Azure DevOps (pipelines, repos, environments)
| Тема | Ссылка |
|---|---|
| YAML schema reference | https://learn.microsoft.com/azure/devops/pipelines/yaml-schema |
| Deployment jobs | https://learn.microsoft.com/azure/devops/pipelines/process/deployment-jobs |
| Deployment life-cycle hooks (on.failure) | https://learn.microsoft.com/azure/devops/pipelines/process/deployment-jobs#descriptions-of-life-cycle-hooks |
| Stages, dependsOn, conditions | https://learn.microsoft.com/azure/devops/pipelines/process/stages |
| Expressions & conditions | https://learn.microsoft.com/azure/devops/pipelines/process/expressions |
| Predefined variables | https://learn.microsoft.com/azure/devops/pipelines/build/variables |
| Variable groups | https://learn.microsoft.com/azure/devops/pipelines/library/variable-groups |
| Link KV secrets to variable groups | https://learn.microsoft.com/azure/devops/pipelines/library/variable-groups#link-secrets-from-an-azure-key-vault |
| az pipelines variable-group create | https://learn.microsoft.com/cli/azure/pipelines/variable-group#az-pipelines-variable-group-create |
| Environments & Approvals | https://learn.microsoft.com/azure/devops/pipelines/process/environments |
| Approvals and checks | https://learn.microsoft.com/azure/devops/pipelines/process/approvals |
| Branch policies | https://learn.microsoft.com/azure/devops/repos/git/branch-policies |
| Build validation policy | https://learn.microsoft.com/azure/devops/repos/git/branch-policies#build-validation |
| az repos policy build | https://learn.microsoft.com/cli/azure/repos/policy/build |
| az repos policy approver-count | https://learn.microsoft.com/cli/azure/repos/policy/approver-count |
| az repos pr create | https://learn.microsoft.com/cli/azure/repos/pr#az-repos-pr-create |
| AzureCLI@2 task | https://learn.microsoft.com/azure/devops/pipelines/tasks/reference/azure-cli-v2 |

### Концепции и best practices
| Тема | Ссылка |
|---|---|
| Service Principal | https://learn.microsoft.com/entra/identity-platform/app-objects-and-service-principals |
| Control plane vs data plane | https://learn.microsoft.com/azure/key-vault/general/security-features#privileged-access |
| RBAC vs Access Policies (KV) | https://learn.microsoft.com/azure/key-vault/general/rbac-access-policy |
| Azure RBAC role propagation | https://learn.microsoft.com/azure/role-based-access-control/troubleshooting#role-assignments-with-identity-not-found |
| Secret rotation | https://learn.microsoft.com/azure/key-vault/secrets/tutorial-rotation |
| Blue-green deployments | https://learn.microsoft.com/azure/app-service/deploy-staging-slots |
| Oryx build system | https://github.com/microsoft/Oryx/blob/main/README.md |
