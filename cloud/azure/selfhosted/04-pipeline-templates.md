# 04. Pipeline templates (NEW в этом коммите)

Главное упражнение из этого набора. Берём дублирующуюся логику тестов и выносим её в
**step template**, который можно подключить из любого пайплайна.

## Зачем

В нашем YAML CI-стейдж раньше выглядел так:
```yaml
- script: |
    python -m venv .venv
    call .venv\Scripts\activate.bat
    pip install -r requirements.txt
    pytest tests/ -v --junitxml=test-results.xml
  displayName: 'Install deps and run tests'

- task: PublishTestResults@2
  displayName: 'Publish test results'
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: 'test-results.xml'
  condition: succeededOrFailed()
```

Если завести второй пайплайн (например, PR-validation без CD-стейджа), пришлось бы скопировать
эти 12 строк. На третьем — обновлять в трёх местах. Решение — template.

## Виды templates в Azure DevOps

| Тип | Что выносится | Подключение |
|---|---|---|
| **Step template** | один или несколько `steps:` | `- template: ...` внутри `steps:` |
| **Job template** | целиком `job:` или `deployment:` | `- template: ...` внутри `jobs:` |
| **Stage template** | целиком `stage:` | `- template: ...` внутри `stages:` |
| **Variable template** | блок `variables:` | `- template: ...` внутри `variables:` |
| **Extends template** | весь pipeline | `extends:` на верхнем уровне |

В этой лабе используем **step template** — самый простой и безопасный.

## Что добавлено

Файл `templates/python-test-steps.yml`:

```yaml
parameters:
  - name: pythonVersion
    type: string
    default: '3.11'
  - name: testsPath
    type: string
    default: 'tests/'
  - name: requirementsFile
    type: string
    default: 'requirements.txt'

steps:
  - script: |
      python -m venv .venv
      call .venv\Scripts\activate.bat
      pip install -r ${{ parameters.requirementsFile }}
      pytest ${{ parameters.testsPath }} -v --junitxml=test-results.xml
    displayName: 'Install deps and run tests (py ${{ parameters.pythonVersion }})'

  - task: PublishTestResults@2
    displayName: 'Publish test results'
    inputs:
      testResultsFormat: 'JUnit'
      testResultsFiles: 'test-results.xml'
    condition: succeededOrFailed()
```

В основном `azure-pipelines.yml` блок CI стал такой:

```yaml
- stage: CI
  jobs:
    - job: TestJob
      steps:
        - template: templates/python-test-steps.yml
          parameters:
            testsPath: 'tests/'
```

12 строк → 3.

## Параметризация

`${{ parameters.X }}` подставляется **на этапе парсинга** YAML (compile-time), не runtime.
Это значит:

- Можно использовать в любом ключе YAML, включая `displayName:`, `condition:`, `inputs:`
- Нельзя получить значение из `$(Build.BuildId)` или другого runtime-source-а
- Параметры могут иметь дефолты, которые легко переопределить из caller-а

Пример вызова с переопределением:
```yaml
- template: templates/python-test-steps.yml
  parameters:
    pythonVersion: '3.12'
    testsPath: 'tests/integration/'
    requirementsFile: 'requirements-dev.txt'
```

## Path filter в triggers (бонус-фича в этом коммите)

Добавлено: trigger игнорирует изменения только в `selfhosted-labs/`:

```yaml
trigger:
  branches:
    include: [main]
  paths:
    exclude:
      - 'selfhosted-labs/*'
      - 'selfhosted-labs/**'
      - '*.md'
```

Это значит:
- Закоммитил только новый markdown в `selfhosted-labs/` → пайплайн **не запускается** (экономия времени)
- Закоммитил `app.py` или `azure-pipelines.yml` → запускается как обычно

**Важно:** этот фильтр срабатывает только для **CI trigger**. Ручной запуск (Run pipeline)
и PR-trigger игнорируют path filter — это правильно, ты можешь захотеть прогнать тесты на
docs-only ветке для проверки.

## Где смотреть в UI

**Что template подгрузился:**
1. Страница run-а `/_build/results?buildId=<N>`
2. Раздел **Stages → CI → TestJob**
3. Раскрой шаги — увидишь `Install deps and run tests (py 3.11)` (название с подставленным параметром)
4. В UI выглядит идентично inline-варианту, разницы пользователь не замечает

**Откуда YAML это собрал:**
1. На странице пайплайна → кнопка **Edit**
2. Откроется веб-редактор YAML, ты в нём видишь только `- template: ...`
3. Чтобы посмотреть содержимое самого template-файла — кликаешь на путь, или открываешь
   `/_git/azure-repo?path=/templates/python-test-steps.yml`

## Антипаттерны

❌ **Слишком много параметров в template** — если template имеет 15 параметров, его уже
   нечитаемо использовать. Лучше разбить на несколько мелких или вынести значения в variable group.

❌ **Условная логика внутри template через `if`** — `${{ if eq(parameters.X, 'foo') }}: ...`
   работает, но быстро превращает шаблон в нечитаемый ад. Лучше иметь два template-файла.

❌ **Step template, который генерирует stages** — нет, не работает; step template — это только
   шаги. Чтобы вернуть стейджи, используй extends template.

❌ **Хранить templates в отдельном репозитории без resources/repositories** — можно, но
   подключение через `resources: repositories: ...` сложнее, и для одного проекта оверкилл.

## Литература

- Templates: https://learn.microsoft.com/azure/devops/pipelines/process/templates
- Path filters: https://learn.microsoft.com/azure/devops/pipelines/repos/azure-repos-git#path-filters
- Expression syntax (`${{ }}` vs `$()` vs `$[]`): https://learn.microsoft.com/azure/devops/pipelines/process/expressions
