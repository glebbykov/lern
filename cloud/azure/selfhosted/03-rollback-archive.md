# 03. Rollback через локальный архив

Замена `Storage Account для rollback-артефактов` из `GUIDE2.md §5`.

## Почему не Universal Packages

`UniversalPackages@0` task падает с ошибкой:
```
##[error]Failed to get artifact tool. Universal Packages are not supported in Azure DevOps Server.
```
То же самое с `PublishPipelineArtifact@1`. См. [01-onprem-limitations.md](01-onprem-limitations.md).

## Реализация

В этом проекте использован гибрид:

1. **Локальный архив на агенте** — основной стораж
   ```
   C:\artifacts\hello-cicd\app-<BuildId>.zip
   ```
   Постоянное хранение, никаких retention policy, доступ через RDP/SMB.

2. **Build Artifact** на самом билде в DevOps — для просмотра и ручного скачивания
   - Видно во вкладке `Artifacts` на странице run-а
   - Файл `hello-cicd-app/app-<BuildId>.zip`, ~23 MB
   - Подвержен retention policy проекта (по умолчанию 30 дней; можно расширить)

## YAML-стейдж публикации

```yaml
- task: ArchiveFiles@2
  displayName: 'Archive deployed app'
  inputs:
    rootFolderOrFile: 'C:\app\hello-cicd'
    includeRootFolder: false
    archiveType: 'zip'
    archiveFile: '$(Build.ArtifactStagingDirectory)\app-$(Build.BuildId).zip'
    replaceExistingArchive: true

- script: |
    if not exist "C:\artifacts\hello-cicd" mkdir "C:\artifacts\hello-cicd"
    copy /Y "$(Build.ArtifactStagingDirectory)\app-$(Build.BuildId).zip" "C:\artifacts\hello-cicd\app-$(Build.BuildId).zip"
  displayName: 'Save rollback archive on agent'

- task: PublishBuildArtifacts@1
  displayName: 'Publish build artifact'
  inputs:
    pathToPublish: '$(Build.ArtifactStagingDirectory)\app-$(Build.BuildId).zip'
    artifactName: 'hello-cicd-app'
    publishLocation: 'Container'
```

Ключевая деталь — **`PublishBuildArtifacts@1`, НЕ `PublishPipelineArtifact@1`** (последний только в Services).

## Откат: runtime parameter + condition

```yaml
parameters:
  - name: rollbackVersion
    displayName: 'Rollback to BuildId (e.g. 14). Empty = normal deploy.'
    type: string
    default: ''

stages:
  - stage: CI
    condition: eq('${{ parameters.rollbackVersion }}', '')
    ...
  - stage: CD
    dependsOn: CI
    condition: and(succeeded(), eq('${{ parameters.rollbackVersion }}', ''))
    ...
  - stage: Rollback
    condition: ne('${{ parameters.rollbackVersion }}', '')
    jobs:
      - deployment: rollback_staging
        environment: staging
        strategy:
          runOnce:
            deploy:
              steps:
                - script: |
                    set ARCHIVE=C:\artifacts\hello-cicd\app-${{ parameters.rollbackVersion }}.zip
                    if not exist "%ARCHIVE%" exit /b 1
                    if exist C:\app\hello-cicd ren C:\app\hello-cicd hello-cicd-prev
                    powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath 'C:\app\hello-cicd' -Force"
                    cd C:\app\hello-cicd
                    if not exist .venv python -m venv .venv
                    call .venv\Scripts\activate.bat
                    pip install -r requirements.txt
```

**Двойное синтаксическое различие** в YAML — важно понимать:

| Синтаксис | Когда подставляется | Где применим |
|---|---|---|
| `$(Var)` | runtime — на агенте при выполнении шага | в `script:`, `inputs:`, env-блоках |
| `${{ parameters.X }}` | compile-time — при парсинге YAML | в `condition:`, `variables:`, ключах task-ов |

`condition: eq('${{ parameters.rollbackVersion }}', '')` подставляется ДО старта пайплайна, поэтому
неактивные стейджи в UI помечаются `Skipped` — они даже не доходят до агента.

## Запуск отката

**Через UI:**
1. http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_build?definitionId=2
2. Кнопка **Run pipeline** справа сверху
3. В форме появится поле "Rollback to BuildId" → ввести например `15`
4. **Run**
5. CI и CD стейджи автоматически Skipped, выполнится только Rollback

**Через REST API:**
```bash
curl -u ":$PAT" -X POST -H "Content-Type: application/json" \
  -d '{
    "definition": {"id": 2},
    "sourceBranch": "refs/heads/main",
    "templateParameters": {"rollbackVersion": "15"}
  }' \
  "$BASE/Lern-azure/_apis/build/builds?api-version=6.0"
```

## Преимущества и недостатки

**Плюсы:**
- 0 зависимостей сверх агента
- 0 retention — архивы лежат пока не удалишь
- Видно через RDP в проводнике

**Минусы:**
- Если агент сдохнет — всё пропало (нет реплицации)
- Нет авто-уборки старых билдов (можно добавить отдельный шаг `forfiles /M *.zip /D -90 /C "cmd /c del @path"`)
- Откат работает только на этом конкретном агенте; если агентов несколько — нужен сетевой шаринг

## Как проверить, что откат сработал

После каждого деплоя на staging добавь HTTP smoke-test, который ловит изменения между версиями:

```yaml
- script: |
    curl -fsS http://localhost:8080/version
  displayName: 'Smoke check'
```

Делаешь PR со сменой ответа `/version` → деплоится новая версия → запускаешь Rollback на старый BuildId → `/version` снова возвращает старое значение. Это и есть proof отката (требует чтобы Flask реально слушал — см. лабу 06).
