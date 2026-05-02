# 07. Multi-environment: staging + production с approval gate

В предыдущих лабах был один environment (`staging`), и любой push в `main` шёл туда автоматически.
Это не production-флоу. В реальной CI/CD-цепочке деплой сначала идёт на staging, проверяется
автоматически (smoke-test) и руками (QA), потом по явной команде катится в production —
причём production обязательно требует подтверждения от человека.

В этой лабе добавлен второй environment `production` с **Approval Gate**. Это та самая фича,
которую мы убирали в начале сессии со staging (потому что она мешала учиться) — на production
она не мешает, она там и нужна.

## Что было сделано

| Что | Где |
|---|---|
| Создан environment `production` (id=2) | http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_environments/2 |
| Добавлен Approval Gate, approver = `Administrator` | вкладка **Approvals and checks** на environment |
| Стейдж `Production` после `CD-Staging` | в YAML `stages:` |
| Production триггерится **только на manual run** | `condition: eq(variables['Build.Reason'], 'Manual')` |
| Production деплой в **отдельную папку и порт** | `C:\app\hello-cicd-prod`, порт 8081 |

## Архитектура двух environments

```
┌─────────────────────────────────────────────────┐
│  Windows VM (ec2amaz-auoc24e)                   │
│                                                 │
│  ┌─────────────────────┐  ┌──────────────────┐ │
│  │ C:\app\hello-cicd   │  │ C:\app\hello-cicd-prod │
│  │ (staging)           │  │ (production)         │
│  │ port 8080           │  │ port 8081            │
│  │ service hello-cicd  │  │ service hello-cicd-prod│
│  └─────────────────────┘  └──────────────────┘ │
│       ↑                          ↑              │
│       └────── self-hosted-pool ──┘              │
└─────────────────────────────────────────────────┘
```

Для учебки достаточно одной VM с двумя инстансами на разных портах. В реальном проде это
были бы две разных VM (или AKS namespace) с одинаковым кодом и разными конфигами/секретами.

## Pipeline-флоу

```
git push в main:
  CI (тесты)
    ↓
  CD-Staging (auto-deploy)
    ↓
  Production:  ❌ Skipped (Build.Reason=IndividualCI, не Manual)


Run pipeline через UI / API (manual queue):
  CI
    ↓
  CD-Staging
    ↓
  Production:
    ⏸️  pending Approval (ждём пока кликнешь Approve в UI)
    ↓
  Production deploy
```

То есть **обычный push не трогает production** — оно требует явного manual run.

## Полный YAML-блок

В `/azure-pipelines.yml` добавлен стейдж `Production`:

```yaml
- stage: Production
  displayName: 'Deploy to Production (manual run only, requires approval)'
  dependsOn: CD
  condition: |
    and(
      succeeded(),
      eq('${{ parameters.rollbackVersion }}', ''),
      eq(variables['Build.Reason'], 'Manual')
    )
  jobs:
    - deployment: deploy_production
      displayName: 'Deploy to production'
      environment: production           # ← из-за этого срабатывает Approval check
      pool:
        name: self-hosted-pool
      variables:
        - name: appFolder
          value: 'C:\app\hello-cicd-prod'
        - name: appPort
          value: '8081'
      strategy:
        runOnce:
          deploy:
            steps:
              - script: |
                  if not exist "$(appFolder)" mkdir "$(appFolder)"
                  xcopy /E /I /Y "$(Build.SourcesDirectory)" "$(appFolder)"
                  ...
                displayName: 'Deploy app to production folder'
```

Ключевые элементы:
- `environment: production` — связь со созданным environment, **именно из-за этой строки** срабатывает Approval check
- `condition: eq(variables['Build.Reason'], 'Manual')` — runtime-условие, проверяет каким способом был запущен билд

`Build.Reason` принимает значения: `Manual`, `IndividualCI`, `BatchedCI`, `Schedule`, `PullRequest`, `BuildCompletion` и т.д. Полный список —
https://learn.microsoft.com/azure/devops/pipelines/build/variables.

## Почему именно `Build.Reason`, а не parameter

Изначально я пытался сделать через runtime parameter `deployToProduction` (boolean или string):
```yaml
parameters:
  - name: deployToProduction
    type: boolean
    default: false
```

И использовать в условии:
```yaml
condition: and(succeeded(), eq('${{ parameters.deployToProduction }}', true))
```

**Это не работает на on-prem** через REST API. Причины:

1. `templateParameters` (новый формат) — Azure DevOps Server **не передаёт** эти значения в YAML
   compile-time выражения через REST API queue request. В UI работает, через API — нет.
2. `parameters` (старый JSON-string формат) — переходит в build-level variables, но в
   `${{ parameters.X }}` compile-time выражения не попадает.

Build.Reason работает потому что это **встроенная переменная**, доступная всегда и независимо от
того, передавали ли её через API или нет. Это и **стандартный способ** различать "ручной запуск
для прод-деплоя" vs "автотриггер для staging" в реальных пайплайнах.

## Approval Gate: как это выглядит в UI

### Шаг 1. Запустить вручную

1. http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_build?definitionId=2
2. Кнопка **Run pipeline** справа сверху
3. Branch: `main` (default)
4. **Run** (никакие параметры менять не нужно, главное — что это **manual queue**)

### Шаг 2. Дождаться подхода стейджа Production

CI и CD-Staging пройдут как обычно (~2-3 минуты). После этого стейдж **Production** перейдёт в
жёлтый статус "Waiting for review".

URL вида: `/_build/results?buildId=N&view=results` — стейдж Production будет с иконкой
паузы и баннером сверху "1 check pending — waiting for review".

### Шаг 3. Approve

Кликни **Review** в баннере → откроется панель **Approval**:
- Approver: Administrator
- Instructions: "Production deploy approval — verify staging is healthy first"
- Поле **Comment** (опционально)
- Кнопки **Approve** / **Reject**

Альтернативный вход — на странице самого environment-а
http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_environments/2 —
будет видна pending approval запись с кнопкой Review.

После клика **Approve** стейдж сразу пойдёт выполняться. Production деплой ляжет в
`C:\app\hello-cicd-prod`.

### Шаг 4. Отказ (Reject)

Если staging выглядит плохо — **Reject**. Стейдж зафейлится с типом `canceled`, билд получит
итоговый статус `failed`. Полезно: в истории видно, что был Reject и кто/когда сделал.

## Approve через REST API

Для скриптов и автоматизации (например, бот, который апрувит после внешних smoke-тестов):

```bash
PAT="..."
BASE="http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection"

# 1. Найти approvalId через timeline билда
APPROVAL_ID=$(curl -s -u ":$PAT" \
  "$BASE/Lern-azure/_apis/build/builds/$BUILD_ID/timeline?api-version=6.0" \
  | jq -r '.records[] | select(.type=="Checkpoint.Approval" and .state=="inProgress") | .id')

# 2. PATCH approve (тело — массив!)
curl -u ":$PAT" -X PATCH -H "Content-Type: application/json" \
  -d "[{\"approvalId\":\"$APPROVAL_ID\",\"status\":\"approved\",\"comment\":\"smoke OK\"}]" \
  "$BASE/Lern-azure/_apis/pipelines/approvals?api-version=6.0-preview.1"
```

Сценарии:
1. **Auto-approve по smoke-результатам** — внешний скрипт прогоняет интеграционные тесты на
   staging и апрувит prod при зелёном статусе
2. **ChatOps** — бот в Slack принимает `/approve build/123` и дёргает API
3. **Scheduled rollout** — запустить production-деплой утром, но фактически выкатить только
   после auto-approve, который сработает после кофе-брейка ☕

⚠️ На on-prem **`pipelinepermissions/environment` API возвращает 401 даже у админа**, см.
[01-onprem-limitations.md](01-onprem-limitations.md). Это касается только API авторизации
пайплайна на самом environment (Permit-клик при первом запуске). API approvals — другой,
работает нормально (мы это уже использовали в начале сессии когда удаляли approval со staging).

## Управление approver-ами

Сейчас approver = `Administrator` (один). В реальности это плохо:
- Один человек заболел/в отпуске → деплой стоит
- Self-approval — не лучшая практика (хотя сейчас по `requesterCannotBeApprover: false` тот, кто
  запустил билд, может сам же его и заапрувить)

Лучшая настройка:
1. Создать группу `prod-approvers` в Project settings → Permissions → New group
2. Добавить туда 2-3 человек
3. В check-е поставить **Approvers: prod-approvers**, **Minimum approvers: 1**,
   **Requester cannot approve own runs: ON**

Делается в UI:
http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_environments/2 →
вкладка **Approvals and checks** → клик на check → **Edit**.

## Другие виды checks (для full picture)

В UI **Approvals and checks** есть несколько типов, кроме Approval:

| Тип | Что делает |
|---|---|
| **Approval** | человек жмёт Approve в UI |
| **Business Hours** | пускать деплой только в рабочие часы (с 9 до 18 МСК, например) |
| **Required template** | стейдж должен использовать определённый template — против "shadow IT" пайплайнов |
| **Evaluate artifact** | проверка тегов/политик образа (для container deploys) |
| **Invoke REST API** | дёрнуть внешний URL и продолжить только при HTTP 200 — для интеграции с внешними gating-системами |
| **Exclusive lock** | максимум один деплой одновременно на этот environment — против race condition |

Для production обычно ставят **Approval + Business Hours + Exclusive lock** — три проверки в стек.

## Где смотреть в UI

| Что | URL |
|---|---|
| Environment production | http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_environments/2 |
| Approvals and checks | там же → **"⋮" → Approvals and checks** |
| История deployments | вкладка **Deployments** на странице environment-а — кто/что/когда катил |
| Pending approvals (всех) | главная страница пайплайнов, вверху баннер "N pending approvals" |

## Альтернативы для других сценариев

| Сценарий | Что использовать вместо Build.Reason |
|---|---|
| Production деплой только с тегов `v*` | `condition: startsWith(variables['Build.SourceBranch'], 'refs/tags/v')` |
| Production только из ветки release/* | `condition: startsWith(variables['Build.SourceBranch'], 'refs/heads/release/')` |
| Опциональный production переключатель | runtime variable + queue-time override (для on-prem требует UI, не работает через API на boolean params) |
| Manual только определённым юзерам | Approval check сам по себе разруливает (только approver-ы могут approve) |

## Troubleshooting

| Симптом | Решение |
|---|---|
| Production стейдж всегда Skipped | Проверь `Build.Reason` через debug-шаг: `echo $(Build.Reason)`. Должно быть `Manual` для UI/API queue, `IndividualCI` для push-триггера |
| Approval не появляется на странице билда | Удостоверься что стейдж дошёл до агента. Если "Skipped" — `condition:` ложен |
| "Waiting for first user to approve" висит вечно | Возможно ты добавил approver, у которого нет прав на сам environment. Дай группе разрешение **User** (не Admin) на security вкладке environment-а |
| Approve кликнул, но deploy не идёт | На on-prem иногда нужно подождать 10-15 секунд после approve — событие подхватывается через poll |
| Deploy в production упал на отсутствии waitress/nssm | Если ты не прошёл [лабу 06](06-real-service-deploy.md) — nssm не установлен. Сначала пройди её, потом запускай эту |

## Литература

- Approvals and checks: https://learn.microsoft.com/azure/devops/pipelines/process/approvals
- Multiple environments: https://learn.microsoft.com/azure/devops/pipelines/process/environments
- Build.Reason values: https://learn.microsoft.com/azure/devops/pipelines/build/variables#build-variables
- Conditions in pipelines: https://learn.microsoft.com/azure/devops/pipelines/process/conditions
