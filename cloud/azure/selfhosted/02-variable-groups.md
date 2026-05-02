# 02. Variable Groups + masked secrets

Замена Azure Key Vault для учебного сценария: секреты хранятся прямо в DevOps Server,
маскируются в логах автоматически. Это покрывает 80% задач Lab 2 без поднятия отдельного
секрет-стораджа.

## Что было сделано

В этом репозитории уже создана и используется variable group `app-secrets`:

| Поле | Значение |
|---|---|
| Имя | `app-secrets` |
| ID | 2 |
| Scope | project-scoped (`Lern-azure`) |
| Переменная | `APP_SECRET_KEY` (тип: secret) |
| Авторизация | Open access — все пайплайны могут читать без Permit |

В `azure-pipelines.yml` группа подключается так:
```yaml
variables:
  - group: app-secrets
```

И используется в шаге через `env:`:
```yaml
- script: |
    if "%APP_SECRET_KEY%"=="" exit /b 1
    echo APP_SECRET_KEY is set
  env:
    APP_SECRET_KEY: $(APP_SECRET_KEY)
```

## Как создать вручную (UI)

1. http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_library
2. **+ Variable group**
3. Имя: `app-secrets`
4. **+ Add** → переменная `APP_SECRET_KEY` → значение → клик 🔒 для пометки как secret
5. **Save**
6. Вкладка **Pipeline permissions** → "..." → **Open access** (либо явно добавить нужные пайплайны)

## Как создать через REST API (как делал я)

```bash
PAT="..."
BASE="http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection"
PROJ_ID="4acf3a09-d16b-4620-b272-ae52827c8b7d"

curl -u ":$PAT" -X POST -H "Content-Type: application/json" \
  -d '{
    "name": "app-secrets",
    "type": "Vsts",
    "variables": {"APP_SECRET_KEY": {"value": "...", "isSecret": true}},
    "variableGroupProjectReferences": [
      {"projectReference": {"id": "'$PROJ_ID'", "name": "Lern-azure"}, "name": "app-secrets"}
    ]
  }' \
  "$BASE/_apis/distributedtask/variablegroups?api-version=6.0-preview.2"
```

Ответ вернёт `id` группы. Дальше:
```bash
GROUP_ID=2
curl -u ":$PAT" -X PATCH -H "Content-Type: application/json" \
  -d '{"allPipelines":{"authorized":true}}' \
  "$BASE/Lern-azure/_apis/pipelines/pipelinepermissions/variablegroup/$GROUP_ID?api-version=5.1-preview.1"
```

## Маскирование в логах

DevOps маскирует **только прямой echo** secret-переменной:
- `echo $(APP_SECRET_KEY)` в логе → `***`
- `echo %APP_SECRET_KEY%` (env-переменная) → `***`

**Производные** не маскируются — это и используется для верификации:
- Длина строки → видна
- SHA256-хеш → виден (это удобный fingerprint без раскрытия)
- Коды ASCII символов → видны
- `base64`, `urlencode`, шифрование — **тоже видно**, это лазейка, через которую секрет может утечь

## Проверка значения (debug-приём)

PowerShell-шаг для безопасного fingerprint без раскрытия:
```yaml
- powershell: |
    $val = $env:APP_SECRET_KEY
    Write-Host "length: $($val.Length)"
    Write-Host "sha256: $([System.BitConverter]::ToString(
      [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($val))).Replace('-','').Substring(0,12))"
  env:
    APP_SECRET_KEY: $(APP_SECRET_KEY)
```

Меняешь значение в UI → меняется fingerprint → подтверждение что новое значение реально применилось.

## Где смотреть в UI

- Сама группа: http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_library?itemType=VariableGroups
- Какие пайплайны её используют: вкладка **Pipeline permissions** на странице группы
- Кто менял: `createdBy / modifiedBy` поля в JSON ответе API (в UI только `Modified by N days ago` без подробностей)

## Чего variable group НЕ заменяет из Key Vault

- Динамические секреты (выдаются по запросу с TTL) — нужен Vault
- Версионирование значений — нет, только текущее значение
- Аудит "кто читал секрет" — нет, только "кто менял"
- Отдельный access scope per consumer — есть только на уровне "пайплайн авторизован/нет"
- Cross-project sharing — нужно явно проставлять в `variableGroupProjectReferences`
