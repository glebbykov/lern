# Лаба 00: Основы процессов в Linux

> Вводная лаба. Задача — **научиться видеть** процессы в системе, понять
> базовые концепции (процесс, PID, fd, сигнал, демон, IPC), и освоить
> ключевые команды диагностики: ps, /proc, kill, strace, lsof.
>
> После неё переходи к **[Лабе 01](../01-lab/readme.md)** — она глубже
> разбирает те же темы: fork/COW, double-fork демоны, realtime-сигналы,
> sigqueue, UNIX-сокеты, POSIX message queues, gdb/ptrace.

---

## Что будет внутри

- `ps`, `pstree`, `top`, `/proc/PID/` — инвентаризация процессов
- fd и перенаправления: почему `> file 2>&1` ≠ `2>&1 > file`
- Сигналы: TERM, KILL, INT, HUP — когда что и почему
- systemd-сервис: unit-файл, start/enable, автоперезапуск
- Зомби: как появляются и кто их убирает
- Фоновые процессы: `&`, `nohup`, `disown`
- Базовый IPC: pipes и FIFO
- Отладка: `strace` и `lsof`

Практики больше, чем теории. Если эти темы уже знакомы — можно сразу [к Лабе 01](../01-lab/readme.md).

---

## Требования к окружению

- **ОС:** Ubuntu 22.04 или 24.04 LTS (в другом дистрибутиве достаточно заменить `apt`)
- **systemd:** нужен для задания 5 (подойдёт обычная VM, WSL2; голый docker без `--privileged` — нет)
- **Права:** `sudo` для задания 5

### Установка

```bash
sudo apt update
sudo apt install -y psmisc lsof python3 strace
```

`psmisc` даёт `pstree` и `killall`, остальное обычно уже есть.

### Создать VM быстро (если нет Linux под рукой)

<details>
<summary>GCP (1 команда)</summary>

```bash
gcloud compute instances create lab-vm \
  --zone=europe-west1-b \
  --machine-type=e2-small \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud

# Подключиться:
gcloud compute ssh lab-vm --zone=europe-west1-b
```
</details>

<details>
<summary>Azure (3 команды)</summary>

```bash
az group create --name rg-lab-vm --location westeurope
az vm create --resource-group rg-lab-vm --name lab-vm \
  --image "Canonical:ubuntu-24_04-lts:server:latest" \
  --size Standard_B1s --admin-username azureuser \
  --ssh-key-values "$(cat ~/.ssh/id_ed25519.pub)"
# В output будет publicIpAddress — SSH на него.
```
</details>

---

## Теория: что такое процесс (читай перед заданиями)

**Процесс** — это запущенная программа в памяти.
У него есть:

| Атрибут | Где посмотреть | Что значит |
|---------|---------------|-----------|
| **PID** — идентификатор | `ps`, `/proc/PID/` | Уникальный номер в системе |
| **PPID** — родитель | `ps -o ppid` | Кто запустил этот процесс |
| **UID** — владелец | `ps -o user` | От чьего имени работает |
| **State** — состояние | `ps -o stat`, `/proc/PID/status` | R (работает), S (спит), Z (зомби), D (ждёт диск) |
| **Файловые дескрипторы (fd)** | `/proc/PID/fd/` | Открытые файлы, сокеты, пайпы |

**PID 1** — это первый процесс (обычно `systemd` или `init`). От него наследуются все остальные.

Когда процесс запускает другой — он делает `fork()` (создаёт копию себя) и потом `exec()` (заменяет код на новый бинарник). Поэтому у каждого процесса есть родитель.

**Полезные ссылки:**
- [Процесс на Linux — Arch Wiki](https://wiki.archlinux.org/title/Process_management)
- [What every developer should know about the Linux process lifecycle](https://blog.thoughtram.io/linux/processes/)
- [proc(5) — man page про /proc](https://man7.org/linux/man-pages/man5/proc.5.html)

---

## Задание 1. Обзор процессов: ps, pstree, /proc

### Практика

```bash
# Все процессы в системе
ps aux | head -20

# Ты и всё что ты запустил в этой сессии
ps -f

# Дерево процессов: от PID 1 до твоего bash
pstree -sp $$
```

`$$` — это PID текущего shell. `-sp` показывает предков + PID в скобках.

### Вопросы

1. Какой процесс у тебя PID 1? Что он делает? (Подсказка: `ps -p 1 -o comm=`.)
2. В выводе `pstree -sp $$` — сколько промежуточных процессов между PID 1 и твоим bash? Что они делают?
3. Запусти `sleep 100 &`, потом снова `pstree -sp $$`. Где в дереве появился `sleep`? Кто его родитель?

**Почитать:**
- [ps(1) — man page](https://man7.org/linux/man-pages/man1/ps.1.html) — форматы `-f`, `-e`, `-o`
- [pstree(1) — man page](https://man7.org/linux/man-pages/man1/pstree.1.html)
- [The Ultimate Guide to ps, top, and htop](https://www.redhat.com/en/blog/ps-pstree-top-linux) *(на английском, очень доступно)*

---

## Задание 2. Интерфейс /proc

Для каждого процесса в `/proc/PID/` доступен набор псевдофайлов, которые ядро генерирует по запросу.

### Практика

```bash
# Запусти фоновый процесс и запомни его PID
sleep 300 &
PID=$!

# Что запущено (командная строка):
cat /proc/$PID/cmdline | tr '\0' ' ' && echo

# Какой бинарник реально выполняется:
readlink /proc/$PID/exe

# В какой папке запущен процесс:
readlink /proc/$PID/cwd

# Состояние и базовая информация:
grep -E "^(Name|State|Uid|PPid|Threads):" /proc/$PID/status

# Почисти:
kill $PID
```

### Вопросы

1. Почему `ls -la /proc/$PID/cmdline` показывает размер 0, хотя `cat` возвращает текст?
   (Подсказка: это не обычный файл на диске — это [«виртуальная файловая система»](https://man7.org/linux/man-pages/man5/proc.5.html).)
2. Зачем нужен `tr '\0' ' '` при чтении `cmdline`? Что внутри файла?
3. Открой `/proc/$$/status` (своего shell'а) и найди строку `VmRSS`. Что это?

**Почитать:**
- [Exploring /proc filesystem — Red Hat](https://www.redhat.com/en/blog/exploring-proc-file-system-linux)
- [/proc on Linux — The Geek Stuff](https://www.thegeekstuff.com/2012/03/linux-proc-file-system/)

---

## Задание 3. Файловые дескрипторы процесса

**Файловый дескриптор (fd)** — это число, через которое процесс обращается к открытому ресурсу.
Всё в Linux — файл (почти): обычные файлы, сокеты, пайпы, устройства — всё это открывается и получает fd.

Каждый процесс стартует с тремя стандартными fd:

| fd | Имя | Куда ведёт по умолчанию |
|----|-----|------------------------|
| 0 | stdin | клавиатура (терминал) |
| 1 | stdout | экран (терминал) |
| 2 | stderr | экран (терминал) |

### Практика

```bash
# Запусти фоновый процесс
sleep 300 &
PID=$!

# Какие fd у него открыты
ls -la /proc/$PID/fd/

# Более информативно — через lsof
lsof -p $PID 2>/dev/null | head -15

kill $PID
```

Теперь перенаправим вывод — и fd изменятся:

```bash
# Запусти sleep, отправив stdout в файл
sleep 300 > /tmp/out.log 2>&1 &
PID=$!

ls -la /proc/$PID/fd/
# fd 1 и fd 2 теперь указывают на /tmp/out.log, а не на терминал!

kill $PID
rm /tmp/out.log
```

### Вопросы

1. Запусти `ls -la /proc/$$/fd/` у своего bash. На что указывают fd 0, 1, 2?
   - Если ты в **обычном терминале** или подключён по SSH с pty — увидишь `/dev/pts/0` (или `/dev/pts/1`, `/dev/pts/2`...).
   - Если запустил bash из `nohup`, `screen` без attach или скрипта — fd могут быть `pipe:[N]` или `/dev/null`.
2. Что такое `/dev/pts/...`? (Подсказка: [pseudo-terminal](https://en.wikipedia.org/wiki/Pseudoterminal).)
3. Почему `> file 2>&1` перенаправляет и stdout, и stderr, а `2>&1 > file` — только stdout?
   (Сложный вопрос — подумай, в каком порядке обрабатываются перенаправления в bash.)

**Почитать:**
- [File descriptors — Wikipedia (RU)](https://ru.wikipedia.org/wiki/Файловый_дескриптор)
- [Bash I/O Redirection — Linux Documentation Project](https://tldp.org/LDP/abs/html/io-redirection.html) — подробно про `>`, `>>`, `2>&1`
- [Pseudo-terminal explained](https://www.linusakesson.net/programming/tty/) — глубже про `/dev/pts/*`

---

## Задание 4. Сигналы и обработка через trap

**Сигнал** — это способ послать сообщение процессу. Некоторые сигналы:

| Сигнал | Номер | Что делает по умолчанию | Как послать |
|--------|-------|-----------------------|-------------|
| `SIGTERM` | 15 | завершить процесс (даёт шанс прибраться) | `kill PID` |
| `SIGKILL` | 9 | убить без вопросов (нельзя перехватить) | `kill -9 PID` |
| `SIGINT` | 2 | прерывание (как Ctrl+C) | `kill -INT PID` |
| `SIGHUP` | 1 | потерян терминал | `kill -HUP PID` |
| `SIGUSR1` | 10 | пользовательский (что скажет программа) | `kill -USR1 PID` |

> **Замечание:** `SIGKILL` (`kill -9`) применяется только если процесс
> не реагирует на `SIGTERM`. Штатное завершение через `SIGTERM`
> позволяет процессу закрыть соединения, сбросить буферы и удалить
> lock-файлы.

### Практика

```bash
# Скрипт с обработчиком SIGTERM: удаляет lock-файл перед выходом
cat > /tmp/graceful.sh << 'EOF'
#!/bin/bash
trap 'echo "SIGTERM received; cleanup"; rm -f /tmp/mylock; exit 0' TERM

touch /tmp/mylock
echo "PID=$$, lock created: /tmp/mylock"
while true; do
  sleep 1
done
EOF
chmod +x /tmp/graceful.sh

# Запусти
/tmp/graceful.sh &
PID=$!
sleep 2
ls -la /tmp/mylock   # файл существует

# Отправка SIGTERM
kill $PID
sleep 1
ls -la /tmp/mylock   # файл удалён — обработчик успел отработать
wait $PID 2>/dev/null

# То же самое через SIGKILL
/tmp/graceful.sh &
PID=$!
sleep 2

kill -9 $PID
sleep 1
ls -la /tmp/mylock   # файл остался — SIGKILL не передаётся в обработчик
rm -f /tmp/mylock /tmp/graceful.sh
wait $PID 2>/dev/null
```

> После `kill -9` bash выведет `-bash: line N: <PID> Killed /tmp/graceful.sh`.
> Это сообщение job control о завершении фонового процесса, не ошибка.

### Вопросы

1. Почему при `SIGTERM` скрипт успел убрать lock, а при `SIGKILL` — нет?
2. Какой сигнал получает процесс, когда ты нажимаешь Ctrl+C в терминале?
   (Проверь: запусти `trap 'echo INT!' INT` в отдельном shell, потом Ctrl+C.)
3. Почему `SIGKILL` (9) не может быть перехвачен или проигнорирован?
   (Подумай: если бы мог — как ты бы убил зависший процесс?)

**Почитать:**
- [signal(7) — man page со всеми сигналами](https://man7.org/linux/man-pages/man7/signal.7.html)
- [A Primer on Linux Signals — DigitalOcean](https://www.digitalocean.com/community/tutorials/linux-signals-primer)
- [bash `trap` — man bash](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#index-trap) *(секция Bourne Shell Builtins)*

---

## Задание 5. Создание systemd-сервиса

**systemd** — менеджер сервисов, PID 1 в большинстве современных дистрибутивов. Он:

- Запускает сервисы при старте системы
- Перезапускает их при падении
- Собирает логи в `journalctl`
- Управляет зависимостями между сервисами

Сервис описывается unit-файлом — текстовый файл в `/etc/systemd/system/имя.service`.

### Практика

```bash
# 1. Простой скрипт, который пишет время каждые 5 секунд
sudo tee /opt/hello.sh >/dev/null << 'EOF'
#!/bin/bash
while true; do
  echo "[$(date '+%H:%M:%S')] Привет от hello.service, PID=$$"
  sleep 5
done
EOF
sudo chmod +x /opt/hello.sh

# 2. Unit-файл
sudo tee /etc/systemd/system/hello.service >/dev/null << 'EOF'
[Unit]
Description=Мой первый systemd сервис

[Service]
Type=simple
ExecStart=/opt/hello.sh
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 3. Запуск
sudo systemctl daemon-reload      # перечитать unit-файлы
sudo systemctl start hello         # запустить
sudo systemctl status hello        # проверить статус
sleep 6
journalctl -u hello -n 5 --no-pager   # логи сервиса
```

### Теперь тест перезапуска

```bash
PID=$(systemctl show hello -p MainPID --value)
echo "До убийства PID=$PID"

sudo kill -9 $PID
sleep 5

NEW_PID=$(systemctl show hello -p MainPID --value)
echo "После убийства PID=$NEW_PID (поменялся: $([ "$PID" != "$NEW_PID" ] && echo yes || echo no))"
```

### Очистка

```bash
sudo systemctl stop hello
sudo rm /etc/systemd/system/hello.service /opt/hello.sh
sudo systemctl daemon-reload
```

### Вопросы

1. Почему после `kill -9` сервис снова запустился — кто это сделал?
2. Что будет, если в unit-файле поставить `Restart=no`? Попробуй.
3. Чем отличается `systemctl start hello` от `systemctl enable hello`?
   (Первое запускает **сейчас**, второе — при **каждой загрузке системы**.)

**Почитать:**
- [systemd.service(5) — man page](https://man7.org/linux/man-pages/man5/systemd.service.5.html)
- [Writing a systemd service — DigitalOcean](https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files)
- [systemd за 5 минут — Habr (RU)](https://habr.com/ru/companies/southbridge/articles/255845/)
- [Restart= options — ArchWiki](https://wiki.archlinux.org/title/Systemd#Service_types)

---

## Задание 6. Зомби-процессы

**Зомби-процесс** — процесс, который завершился, но его родитель ещё не
вызвал `wait()` для получения кода возврата.

Ядро сохраняет запись о таком процессе (PID, exit code, статистика
ресурсов), пока родитель не заберёт её через `wait()`.

### Практика

```bash
# Python-скрипт, создающий трёх зомби-потомков
cat > /tmp/zombies.py << 'EOF'
import os, time

for i in range(3):
    pid = os.fork()
    if pid == 0:
        os._exit(i)   # потомок завершается сразу

# Родитель не вызывает wait() — потомки остаются в состоянии Z
print(f"Parent PID: {os.getpid()}")
print("Sleeping 60s, children are zombies now")
time.sleep(60)
EOF

python3 /tmp/zombies.py &
PARENT=$!
sleep 2

# Найти зомби (колонка STATE = "Z")
echo "--- Зомби-процессы ---"
ps --ppid $PARENT -o pid,state,comm

# Попытка отправить SIGKILL — не действует, процесс уже завершён
for z in $(ps --ppid $PARENT -o pid= --no-headers); do
  kill -9 $z
done
echo "--- После kill -9: зомби сохраняются ---"
ps --ppid $PARENT -o pid,state,comm

# Завершение родителя
kill $PARENT
sleep 2
echo "--- После завершения родителя: зомби удалены ---"
ps --ppid $PARENT -o pid,state,comm 2>&1

rm /tmp/zombies.py
```

### Вопросы

1. Почему SIGKILL не действует на зомби? (Подсказка: процесс должен быть
   жив, чтобы принять сигнал. Зомби уже завершён.)
2. Почему после завершения родителя зомби удаляются из таблицы? Какой
   процесс выполняет их `wait()`? (Подсказка: при завершении родителя
   потомков усыновляет PID 1 — `init`/`systemd`, который периодически
   вызывает `wait()` для своих потомков.)
3. К какому ресурсному лимиту приводит накопление тысяч зомби?
   (Подсказка: `cat /proc/sys/kernel/pid_max`.)

**Почитать:**
- [Zombie process — Wikipedia](https://en.wikipedia.org/wiki/Zombie_process)
- [Linux Process State Codes (including Z) — Red Hat](https://access.redhat.com/solutions/228623)
- [Глава про процессы из «Operating Systems: Three Easy Pieces»](https://pages.cs.wisc.edu/~remzi/OSTEP/cpu-api.pdf) *(PDF, ch. 5 про fork/wait, на английском)*

---

## Задание 7. Фоновые процессы: `&`, nohup, disown

Три способа запустить процесс так, чтобы он продолжал выполняться
после закрытия терминала.

| Способ            | Пережёт закрытие терминала | Механизм |
|-------------------|---------------------------|----------|
| `cmd &`           | нет (получит SIGHUP)      | запуск в фоне |
| `nohup cmd &`     | да                        | `SIG_IGN` на `SIGHUP`, stdout в `nohup.out` |
| `cmd &` + `disown`| да (в bash)               | удаление из job table — `SIGHUP` не отправляется |

### Практика

```bash
# Способ 1 — обычный фон (погибнет после exit shell)
sleep 600 &
jobs

# Способ 2 — nohup
nohup sleep 600 > /tmp/nh.log 2>&1 &
PID2=$!
ls -la /proc/$PID2/fd/   # fd 0→/dev/null, fd 1,2→/tmp/nh.log

# Способ 3 — disown
sleep 600 &
PID3=$!
disown %2 2>/dev/null || disown $PID3
jobs   # его больше нет в списке, но процесс жив
ps -p $PID3

# Очистка
kill $PID2 $PID3 2>/dev/null
rm -f /tmp/nh.log nohup.out
```

### Вопросы

1. Что такое SIGHUP и когда bash отправляет его фоновым процессам?
2. Почему `nohup` перенаправляет stdout в `nohup.out`? (Подсказка: при
   закрытии терминала запись в него вызывает SIGPIPE.)
3. Чем `disown` отличается от `nohup` по механизму действия?

**Почитать:**
- [nohup(1)](https://man7.org/linux/man-pages/man1/nohup.1p.html)
- [bash job control — man bash](https://www.gnu.org/software/bash/manual/html_node/Job-Control.html)

---

## Задание 8. Межпроцессное взаимодействие: pipes и FIFO

Процессам требуется механизм обмена данными. Базовые примитивы —
**каналы** (pipes) и **именованные каналы** (FIFO).

### Практика: anonymous pipe

Оператор `|` в shell создаёт anonymous pipe между двумя процессами.

```bash
# Внутренне: shell вызывает pipe(2), fork(), dup2() для соединения
# fd 1 первого процесса с fd 0 второго.
ps aux | grep bash | wc -l
# Ожидаемо: небольшое число, зависит от сессии.

# Запустим pipeline в фоне и посмотрим его fd через /proc.
sleep 100 | cat &
# $! — PID последней команды pipeline (cat). PID первой команды (sleep):
PID_CAT=$!
PID_SLEEP=$(ps -o pid= --ppid $$ -C sleep | head -1 | tr -d ' ')

echo "sleep=$PID_SLEEP  cat=$PID_CAT"
ls -la /proc/$PID_SLEEP/fd/   # fd 1 → pipe:[N]  (писатель)
ls -la /proc/$PID_CAT/fd/     # fd 0 → pipe:[N]  (читатель, тот же inode)

kill $PID_SLEEP $PID_CAT 2>/dev/null
wait 2>/dev/null
```

> Pipe — пара связанных fd, указывающих на один pipe-inode. Ядро
> выделяет кольцевой буфер, писатель получает fd 1, читатель — fd 0.

### Практика: named pipe (FIFO)

Отличие от обычного pipe — FIFO имеет имя в файловой системе, поэтому
его могут открыть **несвязанные** процессы (разные shell, разные юзеры).

```bash
# Создать FIFO
mkfifo /tmp/myfifo
ls -la /tmp/myfifo
# Ожидаемо:
#   prw-r--r-- 1 user user 0 ... /tmp/myfifo
#   ^ буква 'p' = pipe (FIFO)

# Терминал 1: читаем (блокируется, пока нет писателя)
cat /tmp/myfifo &
READER=$!

# Терминал 1 (или другой): пишем
echo "сообщение через FIFO" > /tmp/myfifo
# В терминале читателя появится: "сообщение через FIFO"

wait $READER 2>/dev/null
rm /tmp/myfifo
```

### Вопросы

1. Почему pipe называется «anonymous» — где у него имя?
2. В чём разница между pipe и FIFO с точки зрения родства процессов?
3. Что ещё бывает для IPC: UNIX-сокеты, POSIX message queues, shared
   memory. В Лабе 01 мы их потрогаем — пока запомни что они существуют.

**Почитать:**
- [pipe(7) — man](https://man7.org/linux/man-pages/man7/pipe.7.html)
- [fifo(7) — man](https://man7.org/linux/man-pages/man7/fifo.7.html)
- [IPC в Linux — обзор](https://habr.com/ru/articles/453008/) *(RU)*

---

## Задание 9. Отладка процессов: strace, lsof

Два инструмента, которые чаще всего спасают на проде, когда процесс
«зависает» или ведёт себя странно:

- **`strace`** — показывает, какие системные вызовы делает процесс
- **`lsof`** — показывает, какие файлы/сокеты/fd он держит

### Практика: strace

```bash
# 1. Статистика syscalls команды ls
strace -c ls /tmp 2>&1 | tail -15
# Колонки: % time | seconds | calls | errors | syscall name
# Увидишь openat, read, write, close и т.д.

# 2. Прицепиться к живому процессу и поймать сигнал
sleep 300 &
PID=$!

# Логируем вывод strace в файл, чтобы можно было прочитать:
sudo strace -p $PID -e trace=signal -o /tmp/strace.log &
STRACE=$!
sleep 1

kill -USR1 $PID     # отправили сигнал
sleep 1

# В логе увидим: --- SIGUSR1 {si_signo=SIGUSR1, ...} ---
cat /tmp/strace.log

# Очистка:
kill $STRACE $PID 2>/dev/null
wait 2>/dev/null
rm -f /tmp/strace.log
```

### Практика: lsof

```bash
# Все listen-сокеты в системе
sudo lsof -iTCP -sTCP:LISTEN -P -n | head -10

# Что открыто конкретным процессом
sleep 300 > /tmp/out.log 2>&1 &
PID=$!
lsof -p $PID
kill $PID; rm -f /tmp/out.log

# Кто держит удалённый файл (классика «df ≠ du»)
dd if=/dev/zero of=/tmp/big.dat bs=1M count=10 2>/dev/null
tail -f /tmp/big.dat &
TPID=$!
rm /tmp/big.dat
sudo lsof +L1 2>/dev/null | head -5   # big.dat (deleted)
kill $TPID
```

### Вопросы

1. Почему `strace` замедляет процесс в 10–100 раз?
   (Подсказка: ядро останавливает процесс **дважды** на каждый syscall —
   вход и выход. Это делается через [ptrace](https://man7.org/linux/man-pages/man2/ptrace.2.html).)
2. Чем `strace` отличается от `gdb`? (strace — syscalls, gdb —
   внутренний state: регистры, стек, переменные. В Лабе 01 потрогаем gdb.)
3. Зачем `lsof +L1` на проде? (Найти «призрачные» файлы, которые
   занимают место, но удалены — частая причина «диск 100%».)

**Почитать:**
- [strace(1) — man](https://man7.org/linux/man-pages/man1/strace.1.html)
- [lsof(8) — man](https://man7.org/linux/man-pages/man8/lsof.8.html)
- [A strace-based debugging tutorial](https://jvns.ca/blog/2021/04/03/what-problems-do-people-solve-with-strace/) *(Julia Evans, англ.)*

---

## Что дальше

Если все 9 заданий прошёл — ты:

- Видишь процессы в системе (ps, pstree, /proc)
- Понимаешь fd и перенаправления
- Умеешь работать с сигналами
- Можешь написать простой systemd-сервис
- Знаешь что такое зомби и когда они опасны
- Запускаешь фоновые процессы тремя способами
- Знаешь базовые механизмы IPC (pipe, FIFO)
- Умеешь подглядывать за процессами через strace и lsof

Следующий шаг — **[Лаба 01](../01-lab/readme.md)**. Там:

- Теория ядра: fork/COW/exec, таблица inode, сигналы realtime vs standard
- Double-fork демоны, privilege separation (почему sshd состоит из 3 процессов)
- strace, lsof, gdb, ptrace — глубокая отладка процессов
- Межпроцессное взаимодействие: pipes, FIFO, UNIX-сокеты, POSIX message queues
- sigqueue и realtime-сигналы с данными
- Практика: diagnostic challenge — найти 4 проблемы не глядя в код

---

## Шпаргалка (распечатать и повесить)

```
                КОМАНДА            ЧТО ДЕЛАЕТ
─────────────────────────────────────────────────────────────
Смотреть      ps aux                  все процессы
              ps -ef                  то же с иерархией
              pstree -sp $$           дерево от PID 1 до меня
              top / htop              интерактивный топ

Инспекция     ls /proc/PID/fd/        открытые fd
              cat /proc/PID/status    состояние, память, треды
              cat /proc/PID/cmdline   чем запущен
              lsof -p PID             всё что держит

Сигналы       kill PID                SIGTERM (вежливо)
              kill -9 PID             SIGKILL (жёстко)
              kill -l                 список всех сигналов
              pkill -f pattern        убить по имени/паттерну
              trap 'action' SIGNAL    перехватить в bash

systemd       systemctl start/stop/restart/status SRV
              systemctl enable SRV    стартовать при загрузке
              journalctl -u SRV -f    смотреть логи

Фоновые       cmd &                   фон (умрёт с shell)
              nohup cmd >log &        фон, переживёт shell
              disown %1               снять из job table
              jobs                    список фоновых

IPC           cmd1 | cmd2             anonymous pipe
              mkfifo /tmp/p           named pipe (FIFO)

Отладка       strace -c cmd           статистика syscalls
              strace -p PID           присоединиться к живому
              lsof -p PID             что открыто у процесса
              lsof +L1                удалённые файлы (держит fd)
```

---

## Файлы лаба

| Файл | Назначение |
|------|-----------|
| `readme.md` | Это задание |
| `solutions/graceful.sh` | Готовое решение задания 4 (сигналы) |
| `solutions/hello.service` | Готовый unit-файл задания 5 |
| `solutions/hello.sh` | Скрипт для задания 5 |
| `solutions/zombies.py` | Скрипт для задания 6 |
