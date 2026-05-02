# 05. Pull Request + Branch Policies

Этот лаб — **пошаговое упражнение для UI**, не выполнялось автоматически. Делается за ~15 минут,
покрывает один из главных навыков работы в Azure DevOps в команде.

## Что будет настроено

На ветке `main` репозитория `azure-repo` будут включены политики:

| Политика | Что делает |
|---|---|
| **Require a minimum number of reviewers** | PR не сливается без N апрувов |
| **Build validation** | PR не сливается, пока пайплайн не прошёл на merge-коммите |
| **Check for linked work items** | требует ссылку на Work Item в PR |
| **Comment requirements** | все комментарии должны быть resolved |
| **Limit merge types** | только squash merge |

## Пошаговое выполнение в UI

### Шаг 1. Включить policies на main

1. http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_settings/repositories
2. Выбрать `azure-repo` → вкладка **Policies**
3. Раздел **Branch Policies** → **main** → **Edit**
4. Включить:
   - **Require a minimum number of reviewers**: 1, **Allow requestors to approve their own changes** = OFF
   - **Check for linked work items**: Required
   - **Check for comment resolution**: Required
   - **Limit merge types**: Squash merge ON, остальные OFF
5. Раздел **Build validation** → **+** → выбрать pipeline `azure-repo` (id=2) → **Save**

### Шаг 2. Создать feature ветку

В UI: `_git/azure-repo` → выпадайка branches вверху → **+ New branch** → `feature/test-pr-flow` от `main`.

Через CLI с PAT:
```bash
git clone http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_git/azure-repo
# (PAT в качестве пароля при запросе)
cd azure-repo
git checkout -b feature/test-pr-flow
echo "# Test change" >> README.md
git add README.md
git commit -m "test: trigger PR flow"
git push -u origin feature/test-pr-flow
```

### Шаг 3. Создать PR

http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_git/azure-repo/pullrequestcreate

Source: `feature/test-pr-flow`, Target: `main`. Заполнить title/description.

### Шаг 4. Увидеть, как policies блокируют merge

На странице PR справа сверху появится секция **Required checks**:

```
✗ Required: At least 1 reviewer required
✗ Required: Build validation - azure-repo (running)
✗ Required: Linked work item required
```

Кнопка **Set auto-complete** заблокирована, **Complete** недоступен.

### Шаг 5. Исправить по очереди

**Linked work item:**
- В правой панели PR → **Work items** → клик → **+** → завести новую User Story (или взять существующую)
- Опционально: можно линковать через commit message — `feat: do thing #42` автоматически линкует с work item #42

**Build:**
- Подождать пока pipeline `azure-repo` отработает на merge-коммите PR
- Если упал — пушить fix-up коммит в feature/test-pr-flow → автоматически перезапустится

**Reviewer:**
- Так как `Allow requestors to approve their own changes = OFF`, тебе нужен второй пользователь
- В учебном setup-е обычно создаётся второй аккаунт `Reviewer` через Project settings → Permissions → +
- Или временно отключить эту политику для теста

### Шаг 6. Slow merge

Когда все checks ✓ зелёные → **Complete** → выбрать **Squash merge** → подтвердить → ветка
автоматически удаляется → main получает один коммит со скваш-историей.

## Что показать преподавателю / коллегам

- Auto-complete: на странице PR кнопка **Set auto-complete** — PR сольётся сам, как только все
  required checks станут ✓. Удобно: оставил PR, ушёл обедать, вернулся — всё уже в main
- Suggestion: на вкладке **Files** PR-а можно прямо в комментарии нажать кнопку **+ Suggest** и
  написать патч в markdown. Автор PR жмёт **Apply** → коммитится правка одним кликом
- Required reviewers vs Optional: ваши инспекторы могут быть обязательными или нет; обязательные
  блокируют merge, опциональные просто рекомендуют

## Где видно историю PR

- Список — http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/DefaultCollection/Lern-azure/_git/azure-repo/pullrequests
- Фильтры — Mine / Active / Completed / Abandoned
- Каждый PR имеет постоянный URL `/pullrequest/<N>` — можно скидывать в чат

## Подключение PR-валидации к другому YAML

Если хочешь, чтобы PR гонял **только тесты** без CD-стейджа (быстрее, безопаснее):

1. Создай отдельный пайплайн `azure-repo-pr` со своим YAML, в нём только `CI` стейдж
2. В YAML добавь:
   ```yaml
   pr:
     branches:
       include: [main]
   trigger: none
   ```
3. В Branch Policy → Build validation → выбери этот новый pipeline вместо основного

Это типовая практика в больших проектах: CI-only pipeline для PR (5 минут), полный pipeline с
CD только на push в main.

## Литература

- Branch policies: https://learn.microsoft.com/azure/devops/repos/git/branch-policies
- PR validation triggers: https://learn.microsoft.com/azure/devops/pipelines/repos/azure-repos-git#pr-triggers
