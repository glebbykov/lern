# 06. Реальный запуск Flask на агенте (waitress + nssm)

Текущий пайплайн только разворачивает файлы в `C:\app\hello-cicd` и запускает `pip install`,
**но сам Flask не запускает**. Поэтому `curl http://ec2-...:8080/health` снаружи не отвечает —
нет процесса на порту, и порт закрыт в AWS Security Group.

Эта лаба превращает пустой деплой в реально работающий веб-сервис. После прохождения
`http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com:8080/health` будет возвращать
`{"status":"healthy"}` снаружи.

## Что нужно перед началом

| Доступ | Зачем |
|---|---|
| RDP к Windows VM `ec2amaz-auoc24e` | установить `nssm` (есть только в AWS, не в DevOps) |
| AWS Console (или CLI) | открыть порт 8080 в Security Group инстанса |
| Возможность пушить в `azure-repo` | обновить `azure-pipelines.yml` |

Если у тебя нет прямого RDP, посмотри в AWS Console → EC2 → Instances → твоя VM → Connect → RDP client. Скачать `.rdp` файл, ввести пароль администратора.

## Часть 1. Установка nssm на агенте (одноразово)

`nssm` (Non-Sucking Service Manager) — стандартный способ обернуть любой `.exe` в Windows-сервис.
Это аналог systemd-юнита для Windows.

### Шаг 1.1. Подключись к VM по RDP

Win+R → `mstsc` → ввести `ec2-16-16-121-34.eu-north-1.compute.amazonaws.com:3389` или адрес из AWS.
Логин: `Administrator`, пароль: тот, что ты задал при первом запуске инстанса (или достаётся в
AWS Console → EC2 → Connect → RDP → Get password с .pem ключом).

### Шаг 1.2. Запусти PowerShell от админа

Кнопка "Поиск" в taskbar → `powershell` → **правый клик → Run as administrator**.

### Шаг 1.3. Установи Chocolatey (если ещё нет)

Chocolatey — менеджер пакетов для Windows, через него nssm ставится одной командой.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

Проверка:
```powershell
choco --version
# должно вывести что-то вроде 2.x.y
```

Если `choco` не находит — закрой и снова открой PowerShell от админа (PATH обновляется только в новой сессии).

### Шаг 1.4. Установи nssm

```powershell
choco install nssm -y
```

Проверка:
```powershell
nssm version
# должно вывести: NSSM 2.24
```

### Шаг 1.5. (Опционально) Прокинь nssm в capabilities агента

Чтобы YAML мог требовать `demands: [nssm]` и не падать на агенте без него:

1. Открой http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com/_admin/_AgentPool
2. Pool → `self-hosted-pool` → агент `my-agent`
3. Вкладка **Capabilities**
4. Раздел **User capabilities** → **+ Add a new capability**
5. Name: `nssm`, Value: `installed`
6. **Save changes**

Это работает только пока агент онлайн. После рестарта агент перепрочитает capabilities — `nssm` останется в user-разделе автоматически.

## Часть 2. Открыть порт 8080 в AWS Security Group

### Через AWS Console

1. Войди в https://eu-north-1.console.aws.amazon.com/ec2/home
2. EC2 → Instances → найди инстанс с DevOps (по тегу или Public DNS `ec2-16-16-121-34...`)
3. Вкладка **Security** внизу → клик по имени Security Group (что-то вроде `sg-XXXXXXXX`)
4. Правый верх — Actions → **Edit inbound rules**
5. **Add rule**:
   - **Type:** Custom TCP
   - **Port range:** `8080`
   - **Source:** `My IP` (для безопасности) или `0.0.0.0/0` (для учебки)
   - **Description:** `Flask hello-cicd lab`
6. **Save rules**

### Через AWS CLI

```bash
# Подменить sg-XXXX на актуальный
aws ec2 authorize-security-group-ingress \
  --region eu-north-1 \
  --group-id sg-XXXXXXXX \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0
```

Проверить что порт открыт:
```bash
aws ec2 describe-security-groups --region eu-north-1 --group-id sg-XXXXXXXX \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`8080`]'
```

## Часть 3. Обновить pipeline YAML

Открой файл `/azure-pipelines.yml` в репо. В стейдже `CD → deploy → steps`, после шага **`Verify secret from variable group`**, добавь блоки:

### Шаг 3.1. Установить waitress

```yaml
- script: |
    cd C:\app\hello-cicd
    call .venv\Scripts\activate.bat
    pip install waitress
  displayName: 'Install waitress (Windows-compatible WSGI)'
```

`waitress` — production-grade WSGI-сервер на чистом Python, работает на Windows. `gunicorn` использует `fork()` и на Windows не запустится.

### Шаг 3.2. Регистрация Windows-сервиса через nssm

```yaml
- powershell: |
    # Stop existing service if any (idempotency)
    $svc = Get-Service hello-cicd -ErrorAction SilentlyContinue
    if ($svc) {
      Write-Host "Stopping existing service hello-cicd..."
      & nssm stop hello-cicd 2>$null
      Start-Sleep -Seconds 2
    }

    # nssm install creates the service if missing, otherwise re-creates it.
    # Set commands are idempotent.
    & nssm install hello-cicd "C:\app\hello-cicd\.venv\Scripts\python.exe" 2>$null
    & nssm set hello-cicd AppParameters "-m waitress --host=0.0.0.0 --port=8080 app:app"
    & nssm set hello-cicd AppDirectory "C:\app\hello-cicd"
    & nssm set hello-cicd AppEnvironmentExtra "APP_SECRET_KEY=$env:APP_SECRET_KEY"
    & nssm set hello-cicd Start SERVICE_AUTO_START
    & nssm set hello-cicd AppStdout "C:\app\hello-cicd\service.stdout.log"
    & nssm set hello-cicd AppStderr "C:\app\hello-cicd\service.stderr.log"
    & nssm set hello-cicd AppRotateFiles 1
    & nssm set hello-cicd AppRotateBytes 10485760

    & nssm start hello-cicd
    Write-Host "Service started"
  displayName: 'Install/restart Flask Windows service'
  env:
    APP_SECRET_KEY: $(APP_SECRET_KEY)
```

Обрати внимание:
- `APP_SECRET_KEY` достаётся из variable group в env-переменную, потом передаётся в сервис через `AppEnvironmentExtra` — секрет на диск не пишется в открытом виде, только в process memory сервиса
- `AppRotateFiles 1` + `AppRotateBytes 10485760` — лог ротируется при достижении 10 MB
- `&` перед `nssm` в PowerShell — это call operator, нужен потому что иначе PowerShell путает параметры

### Шаг 3.3. Smoke-test как gate

```yaml
- powershell: |
    $deadline = (Get-Date).AddSeconds(30)
    $ok = $false
    while ((Get-Date) -lt $deadline) {
      try {
        $r = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $ok = $true; break }
      } catch {
        Start-Sleep -Seconds 2
      }
    }
    if (-not $ok) {
      Write-Error "Smoke test failed: /health did not respond in 30s"
      Write-Host "=== Service status ==="
      & nssm status hello-cicd
      Write-Host "=== Last 50 lines of service.stderr.log ==="
      if (Test-Path C:\app\hello-cicd\service.stderr.log) {
        Get-Content C:\app\hello-cicd\service.stderr.log -Tail 50
      }
      exit 1
    }
    Write-Host "Smoke test passed: HTTP $($r.StatusCode)"
    Write-Host "Body: $($r.Content)"
  displayName: 'Smoke test (gate)'
```

Этот шаг — **пайплайн-гейт**: если Flask не поднимается за 30 секунд, билд падает и в логе уже есть кусок stderr-а с причиной. Это превращает деплой из "файлы скопированы, надеемся что работает" в "сервис проверен и отвечает".

## Часть 4. Проверка после первого запуска

После того как пайплайн зелёный, проверь:

### С самой VM (RDP)

```powershell
# Сервис запущен?
Get-Service hello-cicd
# Status: Running

# Что слушает 8080?
netstat -ano | findstr :8080
# должно показать LISTENING с PID

# Найти процесс
Get-Process -Id <PID>
# должен быть python.exe

# Локальный curl
curl.exe -fsS http://localhost:8080/health
curl.exe -fsS http://localhost:8080/
```

### Снаружи (с твоего компа)

```bash
curl -fsS http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com:8080/health
# {"status":"healthy"}

curl -fsS http://ec2-16-16-121-34.eu-north-1.compute.amazonaws.com:8080/
# {"message":"Hello, Azure DevOps CI/CD!","status":"ok"}
```

Если снаружи 502/таймаут — порт в AWS SG не открыт (см. Часть 2).
Если снаружи 200, изнутри 200 — всё работает.
Если изнутри тоже не отвечает — сервис не запустился, смотри логи (см. ниже).

## Управление сервисом руками

```powershell
# Статус
nssm status hello-cicd

# Стоп / старт / рестарт
nssm stop hello-cicd
nssm start hello-cicd
nssm restart hello-cicd

# Изменить параметры
nssm set hello-cicd AppParameters "-m waitress --host=0.0.0.0 --port=8080 app:app --threads=8"
nssm restart hello-cicd

# Полное удаление (для отладки)
nssm stop hello-cicd
nssm remove hello-cicd confirm
```

## Логи

| Файл | Что |
|---|---|
| `C:\app\hello-cicd\service.stdout.log` | stdout приложения (waitress info, обращения) |
| `C:\app\hello-cicd\service.stderr.log` | stderr (Python tracebacks, ошибки) |
| Event Viewer → Windows Logs → System | NSSM сообщает в System log при старте/остановке/крашах сервиса |

Просмотреть последние строки:
```powershell
Get-Content C:\app\hello-cicd\service.stderr.log -Tail 50 -Wait
# -Wait делает её tail -f аналогом
```

## Troubleshooting

| Симптом | Причина | Решение |
|---|---|---|
| `nssm: command not found` в пайплайне | nssm не в PATH агента | Перезапусти агент после `choco install`; PATH обновляется только в новой сессии |
| Сервис стартует и сразу падает | python -m waitress не нашёл app:app | Проверь что `cd C:\app\hello-cicd` сработал и app.py там есть |
| HTTP 500 в /health | Flask стартанул, но `from app import app` упал | Смотри `service.stderr.log` — обычно ошибка импорта или syntax |
| Снаружи 8080 timeout | AWS SG не открыт | Часть 2 |
| Изнутри localhost:8080 OK, снаружи timeout | NSG/firewall на самой VM | `netsh advfirewall firewall add rule name="Flask 8080" dir=in action=allow protocol=TCP localport=8080` |
| `APP_SECRET_KEY is set` в логе, но в `/config` приходит пустой | env через `AppEnvironmentExtra` пропустил пробелы | Quote значение: `"APP_SECRET_KEY=value with spaces"` |

## Что отсюда переносится в production

| Что | Production-вариант |
|---|---|
| nssm Windows Service | systemd unit на Linux, Docker container на любой ОС |
| `LocalSystem` user (default nssm) | выделенный аккаунт `iis_apppool\hellocicd` или `NetworkService` |
| Порт 8080 наружу | через nginx/IIS reverse-proxy, TLS на 443, 8080 закрыт |
| `service.stderr.log` файлом | агрегация в Loki/CloudWatch/Splunk |
| Smoke только `/health` | + проверка `/version` совпадает с `$(Build.BuildId)`, + проверка `/config` отдаёт ожидаемые env |
| Один процесс waitress | несколько worker-ов, или waitress + supervisor для перезапуска при крашах |

## Литература

- nssm docs: https://nssm.cc/usage
- waitress docs: https://docs.pylonsproject.org/projects/waitress/
- Pipeline YAML expressions: https://learn.microsoft.com/azure/devops/pipelines/process/expressions
