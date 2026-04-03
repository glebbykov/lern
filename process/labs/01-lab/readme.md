# Домашнее задание: Процессы, дескрипторы, демоны в Linux

---

## Требования (установить до начала)

```bash
sudo apt install -y gcc build-essential psmisc tmux lsof python3 strace sysstat
```

---

## Задание 1. Теория: анатомия файлового дескриптора

Объясни своими словами: что происходит на уровне ядра, когда процесс вызывает `open("/tmp/file.txt", O_RDWR)`.

В ответе должны фигурировать три структуры:

- Таблица fd процесса (массив указателей в task_struct)
- Системная таблица открытых файлов (file description / struct file)
- Таблица inode

Нарисуй схему связи этих трёх таблиц.

**Вопросы:**

1. Почему после `fork()` два процесса могут писать в один и тот же файл через разные fd — и что будет с позицией чтения/записи?
2. Чем отличается `dup2(fd, 1)` от повторного `open()` того же файла?

---

## Задание 2. Теория: жизненный цикл процесса

Опиши полный путь процесса от создания до удаления из таблицы:

```text
fork() → состояния (R, S, D, T, Z, X) → exit() → wait()
```

Для каждого перехода между состояниями укажи: что вызывает переход (системный вызов, сигнал, событие ядра).

**Вопросы:**

1. Почему процесс в D-state нельзя убить даже через SIGKILL?
2. Чем отличается SIGSTOP от SIGTSTP?
3. Почему ядро не удаляет запись из таблицы процессов сразу после `exit()`, а ждёт `wait()` от родителя? Какая информация хранится в этой записи и кому она нужна?

---

## Задание 3. Теория: fork, exec, clone

Объясни разницу между `fork()`, `vfork()`, `clone()` и `exec()`.

В ответе раскрой:

- Что такое Copy-on-Write и почему `fork()` быстрый даже для процесса с 10 ГБ памяти
- Зачем `vfork()` существует, если есть COW (историческая причина и когда он до сих пор полезен)
- Как `clone()` связан с созданием потоков — какие флаги (CLONE_VM, CLONE_FILES, CLONE_FS) что разделяют
- Почему семейство `exec()` (execve, execvp, execl) не создаёт новый процесс, а заменяет текущий

Приведи пример, когда `fork()` без `exec()` имеет смысл — не учебный, а реальный (Redis, PostgreSQL, Apache).

---

## Задание 4. Практика: карта процессов твоей сессии

Выполни:

```bash
pstree -sp $$
```

Нарисуй полную цепочку от PID 1 до твоего bash.

Для каждого процесса в цепочке выясни через `/proc/PID/status` и `ps`:

- UID
- Состояние
- Количество потоков

Объясни роль каждого процесса.

Если в `pstree` видишь `sshd` — объясни, зачем три процесса sshd (master, privileged, session) и как работает privilege separation.

---

## Задание 5. Практика + теория: расследование fd и перенаправления

### Практическая часть

```bash
# Создай большой файл, чтобы передача заняла время
dd if=/dev/urandom of=/tmp/bigfile.dat bs=1M count=50

# Запусти http-сервер
python3 -m http.server 8888 -d /tmp &
SERVER_PID=$!

# --limit-rate замедляет curl — он живёт дольше, успеваешь его инспектировать.
# Загружаем созданный 50 МБ файл со скоростью 10 КБ/с → curl проживёт ~80 мин.
curl --limit-rate 10k http://localhost:8888/bigfile.dat > /dev/null &
CURL_PID=$!

echo "server=$SERVER_PID  curl=$CURL_PID"
```

Пока оба процесса живы, исследуй `/proc/PID/fd/` каждого:

- Сколько fd открыто
- Какие из них сокеты, какие файлы
- Найди listen-сокет сервера
- Определи, какой fd отвечает за соединение с curl

```bash
# Сколько fd открыто
ls /proc/$SERVER_PID/fd/ | wc -l
ls /proc/$CURL_PID/fd/ | wc -l

# Тип каждого fd
ls -la /proc/$SERVER_PID/fd/
# Найди socket:[...] — это сокеты
# Найди /dev/null, /dev/pts — стандартные

# Через lsof — сетевые соединения
lsof -p $SERVER_PID -i
lsof -p $CURL_PID -i

# Очистка
kill $SERVER_PID $CURL_PID 2>/dev/null
rm -f /tmp/bigfile.dat
```

### Теоретическая часть

1. Объясни, почему порядок `> file 2>&1` и `2>&1 > file` даёт разный результат. Нарисуй, куда указывают fd 1 и fd 2 после каждого шага в обоих случаях.
2. Объясни, что внутри делает конструкция `cmd1 | cmd2` — какие системные вызовы (`pipe`, `fork`, `dup2`, `close`, `exec`) и в каком порядке.

---

## Задание 6. Теория + практика: сигналы в глубину

### Теоретическая часть

Ответь на вопросы:

1. Как ядро доставляет сигнал процессу — в какой момент проверяется маска pending signals?
2. Почему стандартные сигналы (1–31) не образуют очередь, а realtime-сигналы (34–64) образуют? В чём практическая разница?
3. Что произойдёт, если послать SIGTERM процессу в D-state (uninterruptible sleep)?
4. Объясни разницу между `signal()` и `sigaction()` в C (или `trap` в bash).

### Практическая часть

Напиши скрипт `worker.sh` (решение см. в `solutions/worker.sh`):

- При SIGTERM — graceful shutdown: вывести сообщение, удалить lock-файл `/tmp/worker.lock`, выйти
- При SIGINT — игнорировать
- При SIGUSR1 — вывести количество итераций и uptime
- Основной цикл: каждые 2 секунды писать «Working...», создать lock-файл при старте

Протестируй:

```bash
./worker.sh &
PID=$!
kill -SIGUSR1 $PID   # должен показать статистику
kill -SIGINT $PID    # должен проигнорировать
kill -SIGTERM $PID   # должен удалить lock и выйти
ls /tmp/worker.lock  # не должно быть
```

Затем запусти повторно и убей через `kill -9`. Остался ли lock-файл? Объясни почему.

---

## Задание 7. Практика + теория: удалённый файл и inode

### Практическая часть

Напиши скрипт, который:

```bash
# 1. Создай файл 10 МБ
dd if=/dev/zero of=/tmp/big.txt bs=1M count=10

# 2. Открой через fd
exec 3</tmp/big.txt

# 3. Удали файл
rm /tmp/big.txt

# 4. Докажи что файл исчез из файловой системы
ls /tmp/big.txt 2>&1   # No such file or directory

# 5. Докажи что данные доступны через fd
wc -c <&3              # 10485760 (10 MiB)

# 6. Найди файл через /proc
ls -la /proc/$$/fd/3   # /tmp/big.txt (deleted)

# 7. Найди через lsof +L1 (нужен root для чужих процессов)
lsof +L1 2>/dev/null | grep big.txt

# 8. Закрой fd — теперь ядро освободит inode и блоки
exec 3<&-
```

### Теоретическая часть

Объясни механизм через понятие inode и счётчик ссылок:

1. Что такое hard link и почему `rm` на самом деле вызывает `unlink()`?
2. При каких двух условиях inode реально освобождается?
   - link count = 0
   - открытых fd = 0
3. Как это приводит к ситуации «df показывает 100%, du показывает 50%» на production?
4. Как диагностировать через `lsof +L1`?

```bash
# lsof видит fd других процессов только с правами root:
sudo lsof +L1
# или через /proc своего shell'а:
ls -la /proc/$$/fd/
```

---

## Задание 8. Теория + практика: демоны и double-fork

### Теоретическая часть

Объясни каждый шаг classic daemon creation:

| Шаг | Действие | Зачем |
|-----|---------|-------|
| a | Первый `fork()`, родитель завершается | ? |
| b | `setsid()` | Что такое сессия, группа процессов, управляющий терминал? |
| c | Второй `fork()` | Почему лидер сессии опасен? |
| d | `chdir("/")` | При чём тут umount? |
| e | `umask(0)` | Что наследуется от родителя? |
| f | Закрытие fd 0, 1, 2 | Почему запись в закрытый pts даёт SIGPIPE? |

Объясни: почему с systemd не нужен double-fork и чем отличаются Type=simple, Type=forking, Type=notify.

**Дополнительно (необязательно):** посмотри реализацию double-fork в `process/daemon/simpled.c`.
Сборка и запуск:

```bash
gcc process/daemon/simpled.c -o simpled
sudo ./simpled
ps aux | grep simpled
sudo tail -f /var/log/simpled.log
```

### Практическая часть

Создай systemd-сервис для скрипта, который каждые 30 секунд пишет использование диска
(решение см. в `solutions/diskmon.service`).

Скрипт `/opt/diskmon.sh`:

```bash
#!/bin/bash
trap 'echo "Shutting down..."; exit 0' TERM
while true; do
    echo "[$(date)] $(df -h / | tail -1)"
    sleep 30
done
```

Unit-файл `/etc/systemd/system/diskmon.service`:

- Type=simple
- Restart=on-failure
- RestartSec=5
- LimitNOFILE=4096

Протестируй:

```bash
sudo cp solutions/diskmon.sh /opt/diskmon.sh
sudo chmod +x /opt/diskmon.sh
sudo cp solutions/diskmon.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl start diskmon
sudo systemctl status diskmon
journalctl -u diskmon -f

# Убей процесс — должен перезапуститься.
# ВАЖНО: kill без -9 отправляет SIGTERM. Скрипт перехватывает SIGTERM
# через trap → выполняет exit 0 → systemd видит код 0 → Restart=on-failure
# НЕ перезапускает (on-failure срабатывает только при ненулевом exit).
# Используй kill -9 (SIGKILL), чтобы гарантированно получить exit 137:
sudo kill -9 $(systemctl show diskmon -p MainPID --value)
sleep 6
sudo systemctl status diskmon   # PID изменился?

sudo systemctl enable diskmon
systemctl is-enabled diskmon

# Очистка:
sudo systemctl stop diskmon
sudo systemctl disable diskmon
sudo rm /etc/systemd/system/diskmon.service /opt/diskmon.sh
sudo systemctl daemon-reload
```

---

## Задание 9. Теория: /proc как интерфейс к ядру

### Теоретическая часть

Ответь на вопросы:

1. Почему файлы в /proc имеют размер 0 байт, но содержат данные?
2. Что значит «виртуальная файловая система» — где физически хранятся данные, которые возвращает `cat /proc/PID/status`?

### Практическая часть

Запусти `sleep 600 &` и для этого процесса извлеки из /proc:

```bash
PID=$!

# Командная строка:
cat /proc/$PID/cmdline | tr '\0' ' ' && echo

# Бинарник:
readlink /proc/$PID/exe

# Рабочий каталог:
readlink /proc/$PID/cwd

# Файловые дескрипторы:
ls -la /proc/$PID/fd/

# Карта памяти:
cat /proc/$PID/maps | head -15

# Лимиты:
cat /proc/$PID/limits

# Переключения контекста:
grep ctxt /proc/$PID/status
```

По карте памяти объясни значение колонок:

- Адреса (диапазон виртуальных адресов)
- Права (rwxp — что значит каждая буква, что значит p vs s)
- Что такое `[heap]`, `[stack]`, загруженные `.so`

По лимитам объясни:

- Что такое soft и hard limit
- Кто может менять какой

По переключениям контекста объясни:

- `voluntary_ctxt_switches` — что означает, когда их много
- `nonvoluntary_ctxt_switches` — что означает, когда их много
- Какой тип преобладает у I/O-bound процесса? У CPU-bound?

```bash
kill $PID
```

---

## Задание 10. Теория + практика: зомби, сироты, усыновление

### Теоретическая часть

Объясни механизм:

1. Почему ядро сохраняет запись зомби — какую информацию хранит (exit status, rusage, accounting data)?
2. Кто и зачем вызывает `wait()` — и какие варианты существуют (wait, waitpid, waitid, WNOHANG)?
3. Что происходит при накоплении зомби (исчерпание pid_max)?
4. Заполни таблицу:

| Характеристика | Зомби | Сирота |
|---------------|-------|--------|
| Процесс жив? | | |
| Родитель жив? | | |
| PPID | | |
| Нужно вмешательство? | | |

### Практическая часть

Напиши `zombie_farm.py`:

```python
import os, time

for i in range(5):
    pid = os.fork()
    if pid == 0:
        os._exit(i)  # потомок сразу завершается

# Родитель НЕ вызывает wait()
print(f"Parent PID: {os.getpid()}")
print("Sleeping 120 seconds without wait()...")
time.sleep(120)
```

Запусти и в другом терминале:

```bash
# Найди зомби:
ps aux | awk '$8 ~ /Z/'

# Попробуй kill -9 на зомби:
kill -9 <ZOMBIE_PID>
ps aux | awk '$8 ~ /Z/'   # всё ещё здесь?

# Убей родителя:
kill <PARENT_PID>
ps aux | awk '$8 ~ /Z/'   # зомби исчезли?
```

Объясни цепочку: убийство родителя → зомби становятся сиротами → init усыновляет → init вызывает wait() → записи удалены.

---

## Задание 11. Практика + теория: nohup, disown, tmux — сравнение через fd

> **Требование:** убедись что tmux установлен:
> ```bash
> command -v tmux || sudo apt install -y tmux
> ```

### Практическая часть

Запусти `sleep 600` тремя способами:

```bash
# Способ 1:
nohup sleep 600 > /tmp/nh.log 2>&1 &
PID1=$!

# Способ 2:
sleep 600 &
PID2=$!
disown %1

# Способ 3:
tmux new -d -s test 'sleep 600'
PID3=$(pgrep -f "sleep 600" | tail -1)
```

Для каждого процесса проверь:

```bash
ls -la /proc/$PID/fd/
```

Заполни таблицу:

| Метод | fd 0 → | fd 1 → | fd 2 → | Переживёт закрытие терминала? |
|-------|--------|--------|--------|-------------------------------|
| nohup | | | | |
| disown | | | | |
| tmux | | | | |

```bash
# Очистка:
kill $PID1 $PID2 $PID3 2>/dev/null
tmux kill-session -t test 2>/dev/null
```

### Теоретическая часть

Объясни, что происходит при закрытии SSH:

1. Какой сигнал получают процессы сессии? (SIGHUP)
2. Почему nohup защищает? (SIG_IGN)
3. Почему disown защищает? (удаление из job table)
4. Почему tmux защищает? (отдельная сессия с собственным pts)
5. Что произойдёт с обычным `sleep 600 &` без защиты — какие два механизма его убьют? (SIGHUP + запись в закрытый pts → SIGPIPE)

---

## Задание 12. Практика + теория: стресс-тест и лимиты fd

### Практическая часть

Напиши Python-скрипт `fd_stress.py`:

```python
import os

fds = []
try:
    while True:
        fd = os.open('/dev/null', os.O_RDONLY)
        fds.append(fd)
except OSError as e:
    print(f"Упёрлись в лимит!")
    print(f"Последний успешный fd: {fds[-1]}")
    print(f"Всего открыто: {len(fds)}")
    print(f"Ошибка: {e}")
finally:
    for fd in fds:
        os.close(fd)
```

Запусти с ограничением:

```bash
ulimit -n 256
python3 fd_stress.py
```

Какой номер fd был последним? Совпадает ли с `ulimit -n` и почему может не совпадать?

### Теоретическая часть

Объясни разницу между тремя уровнями лимитов:

| Уровень | Где настраивается | Что ограничивает |
|---------|------------------|-----------------|
| Per-process | `ulimit -n` / `LimitNOFILE` в systemd | Один процесс |
| Per-user | `/etc/security/limits.conf` | Все процессы пользователя |
| System-wide | `/proc/sys/fs/file-max` / `sysctl fs.file-max` | Вся система |

Какой из трёх сработает первым?

Объясни, почему для nginx с 10000 соединений нужно минимум 20000 fd (upstream + client), и где настраивается:

- `worker_rlimit_nofile` в nginx.conf
- `LimitNOFILE` в systemd unit
- `fs.file-max` в sysctl

---

## Задание 13. Комплексная диагностика

### Практическая часть

Запусти:

```bash
bash lab_helper.sh   # выбери опцию 5 (diagnostic challenge)
```

Не читая код скрипта, используя только `ps`, `/proc`, `lsof`, `strace`, найди **четыре** проблемы.

### Отчёт

Для каждой проблемы оформи мини-отчёт:

```markdown
## Проблема N

**Симптомы:** что заметил (высокий CPU, много fd, зомби, диск...)

**Диагностика:** какие команды выполнил и что увидел
  $ команда1
  (вывод)
  $ команда2
  (вывод)

**Причина:** что именно не так

**Решение:** как исправить
```

### Теоретический вопрос

Составь универсальный алгоритм диагностики «непонятного» процесса на production:

- Какие команды и в каком порядке ты выполнишь
- Что на каждом шаге узнаёшь
- Когда переходишь к следующему инструменту

```text
Шаг 1: ps aux / top → ...
Шаг 2: /proc/PID/... → ...
Шаг 3: lsof -p PID → ...
Шаг 4: strace -p PID → ...
Шаг 5: /proc/PID/status (context switches) → ...
```

---

## Задание 14. Практика + теория: strace — трассировка системных вызовов

### Теоретическая часть

Ответь на вопросы:

1. Что такое системный вызов и чем он отличается от вызова библиотечной функции?
2. Как `strace` перехватывает syscalls (ptrace API)?
3. Почему `strace` замедляет процесс в 10–100 раз?
4. Чем `strace -e trace=network` отличается от `strace -e trace=file`?

### Практическая часть

**Упражнение A: анатомия простой команды**

```bash
# Трассировка ls — увидеть системные вызовы
strace -c ls /tmp 2>&1 | tail -20
# -c → статистика: сколько раз каждый syscall вызван

# Полная трассировка с временем
strace -ttt -T ls /tmp 2>/tmp/strace_ls.log
head -30 /tmp/strace_ls.log
```

Найди в выводе:
- `execve()` — запуск бинарника
- `openat()` — открытие файлов/директорий
- `getdents64()` — чтение содержимого директории
- `write()` — вывод на stdout

**Упражнение B: диагностика зависшего процесса**

```bash
# Запусти процесс, который «зависает» на DNS
strace -p $(pgrep -f "python3 -m http.server" | head -1) -e trace=network 2>&1 | head -20
# Или на новом процессе:
strace -e trace=network python3 -c "import urllib.request; urllib.request.urlopen('http://httpbin.org/delay/5')" 2>&1
```

**Упражнение C: подсчёт syscalls**

```bash
# Сравни два способа копирования файла:
dd if=/dev/zero of=/tmp/testfile bs=1M count=10 2>/dev/null

strace -c cp /tmp/testfile /tmp/testfile2 2>&1 | tail -5
strace -c dd if=/tmp/testfile of=/tmp/testfile3 bs=4k 2>&1 | tail -5
strace -c dd if=/tmp/testfile of=/tmp/testfile4 bs=1M 2>&1 | tail -5

# Сколько раз вызван read/write для каждого bs?
# Почему больший bs = меньше syscalls = быстрее?

rm -f /tmp/testfile*
```

**Упражнение D: strace работающего процесса**

```bash
sleep 300 &
PID=$!

# Подключиться к работающему процессу
sudo strace -p $PID -e trace=signal 2>&1 &
STRACE_PID=$!

# Послать сигнал и увидеть его в strace
kill -USR1 $PID
sleep 1
kill $STRACE_PID $PID 2>/dev/null
```

---

## Задание 15. Теория + практика: cgroups и namespaces — основа контейнеров

### Теоретическая часть

Ответь на вопросы:

1. Что такое cgroup и какие ресурсы можно ограничить (cpu, memory, io, pids)?
2. Чем отличаются cgroup v1 и cgroup v2? Какой используется в твоей системе?
3. Что такое namespace? Перечисли 7 типов (mnt, pid, net, uts, ipc, user, cgroup) и что каждый изолирует.
4. Как `docker run` использует cgroups + namespaces вместе?

### Практическая часть А: cgroups — ограничение ресурсов

```bash
# Какая версия cgroup?
mount | grep cgroup
# cgroup2 → unified hierarchy

# Создать cgroup и ограничить память до 50 МБ
sudo mkdir -p /sys/fs/cgroup/lab_test
echo "52428800" | sudo tee /sys/fs/cgroup/lab_test/memory.max
echo "0" | sudo tee /sys/fs/cgroup/lab_test/memory.swap.max

# Запустить процесс в этой cgroup
sudo bash -c 'echo $$ > /sys/fs/cgroup/lab_test/cgroup.procs && python3 -c "
import os
data = []
try:
    while True:
        data.append(b\"x\" * 1024 * 1024)  # +1 MB каждую итерацию
        print(f\"Allocated: {len(data)} MB\")
except MemoryError:
    print(f\"MemoryError at {len(data)} MB\")
"'
# Процесс будет убит OOM Killer при ~50 МБ

# Проверить OOM events
cat /sys/fs/cgroup/lab_test/memory.events
# oom_kill должен быть > 0

# Очистка
sudo rmdir /sys/fs/cgroup/lab_test
```

### Практическая часть Б: namespaces — изоляция

```bash
# Создать новый PID namespace
sudo unshare --pid --fork --mount-proc bash -c '
    echo "Внутри нового PID namespace:"
    echo "Мой PID: $$"
    ps aux
    echo "---"
    echo "Всего процессов: $(ps aux | wc -l)"
    echo "Снаружи их сотни, здесь — только bash и ps"
'

# Создать новый UTS namespace (hostname)
sudo unshare --uts bash -c '
    hostname container-lab
    echo "Hostname внутри: $(hostname)"
'
echo "Hostname снаружи: $(hostname)"
# Hostname хоста не изменился!

# Создать новый NET namespace
sudo unshare --net bash -c '
    echo "Сетевые интерфейсы внутри:"
    ip link show
    echo "Только loopback!"
'
```

**Вопросы к практике:**

1. Почему внутри PID namespace `ps aux` показывает единицы процессов?
2. Что произойдёт, если процесс внутри PID namespace завершит PID 1?
3. Как cgroup limits + namespaces вместе создают «контейнер»?

---

## Файлы лаба

| Файл | Назначение |
|------|-----------|
| `readme.md` | Это задание |
| `lab_helper.sh` | Скрипт с меню (zombie farm, fd leak, CPU/IO-bound, diagnostic challenge) |
| `solutions/worker.sh` | Решение задания 6 |
| `solutions/diskmon.sh` | Скрипт мониторинга диска (задание 8) |
| `solutions/diskmon.service` | Systemd unit-файл (задание 8) |
| `answers.md` | Ответы на теоретические вопросы |
