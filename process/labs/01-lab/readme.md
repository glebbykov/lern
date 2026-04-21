# Лаба 01: Процессы и управление ими — продвинутый уровень

> Продолжение [Лабы 00](../00-basics/readme.md). Там ты научился **видеть**
> процессы; здесь — **понимать** как они устроены в ядре и **чинить** их
> на production.

## Что ты узнаешь

- **Как устроен процесс в ядре:** `task_struct`, таблица fd, inode,
  состояния (R/S/D/T/Z/X), переключения контекста
- **Fork / COW / exec:** почему fork() с 10 ГБ памяти занимает миллисекунды
- **Сигналы вглубь:** стандартные vs realtime, `sigqueue`, `sigaction`,
  доставка и блокировка
- **Демоны:** double-fork, `setsid()`, privilege separation, Type= в systemd
- **IPC:** pipes, FIFO, UNIX-сокеты, POSIX message queues — когда что брать
- **Отладка:** strace, lsof, gdb, ptrace — и как написать свой мини-strace
- **Диагностика:** алгоритм расследования «непонятного» процесса на production

## Карта лабы (задание → тема)

| Задание | Тема | Тип |
|---------|------|-----|
| 1, 5, 7, 12 | Файловые дескрипторы | теория + практика |
| 2, 3, 4, 9 | Процессы: жизненный цикл, fork, /proc | теория + практика |
| 6 | Сигналы (standard, RT, pkill, sigqueue) | теория + практика |
| 8 | Демоны (double-fork, systemd Type=) | теория + практика |
| 10 | Зомби, сироты, усыновление | теория + практика |
| 11 | Фоновые: nohup, disown, tmux | практика |
| 13 | Комплексная диагностика (4 проблемы) | практика |
| 14 | Отладка: strace, lsof, gdb, ptrace | теория + практика |
| 15 | IPC: pipe, FIFO, UNIX socket, POSIX mq | теория + практика |

## Как проходить

1. Пройди Лабу 00, если ещё не (эта строится на её базе).
2. Иди по заданиям по порядку — они ссылаются друг на друга.
3. В задании ответь на теорию сам, потом сверься с `answers.md`.
4. Если застрял на практике — готовые решения в `solutions/`.
5. Задание 13 — контрольная: диагностируй 4 процесса не читая код.

---

## Требования к окружению

- **ОС:** Ubuntu 22.04 LTS или 24.04 LTS (другие дистрибутивы тоже работают, но команды ниже — для apt)
- **Права:** `sudo` для systemd, `unshare`, cgroup, `lsof +L1`
- **systemd:** лаба требует полноценный systemd PID 1 (обычная VM или bare metal; WSL2 работает; docker container без `--privileged` — нет)
- **Диск:** ~200 МБ свободного места (dd-файлы до 50 МБ + временные артефакты)

### Установка зависимостей

```bash
sudo apt update
sudo apt install -y gcc build-essential psmisc tmux lsof python3 strace sysstat gdb
```

| Пакет | Зачем |
|-------|-------|
| `gcc`, `build-essential` | компиляция C-примеров (sigqueue, mini_strace, POSIX mq) |
| `psmisc` | `pstree`, `killall`, `fuser` |
| `tmux` | задание 11 (сравнение с nohup/disown) |
| `lsof` | задания 5, 7, 12, 13, 14 |
| `strace` | задания 13, 14 |
| `gdb` | задание 14 (attach к живому процессу) |
| `python3` | скрипты-демонстрации (fork, fd leak) |
| `sysstat` | `iostat` — для I/O-bound диагностики |

> **Совет:** если нет Linux-машины под рукой — VM с Ubuntu 24.04 в любом
> облаке (GCP/Azure/Hetzner) разворачивается за 2–3 минуты; 1 vCPU / 1 GB
> RAM хватит. Инструкции — в README Лабы 00.

---

## Задание 1. Теория: анатомия файлового дескриптора

> **TL;DR:** fd — это индекс в таблице процесса, которая указывает на
> системную `struct file` (offset, флаги), которая указывает на inode
> (содержимое файла). Три уровня. После `fork()` таблица копируется, но
> `struct file` общая → общий offset.

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

> **TL;DR:** `fork()` → процесс живёт в состояниях R/S/D/T → `exit()` →
> становится Z (зомби) → родитель делает `wait()` → запись удаляется
> (X). Без `wait()` запись висит, и это память ядра.

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

> **TL;DR:** `fork()` создаёт копию процесса (через COW — дёшево даже
> для 10 ГБ), `exec()` заменяет код и данные в текущем PID, `clone()`
> — обобщённый fork с флагами (что разделять). Потоки = clone с
> `CLONE_VM|CLONE_FILES|CLONE_FS|CLONE_SIGHAND`.

Объясни разницу между `fork()`, `vfork()`, `clone()` и `exec()`.

В ответе раскрой:

- Что такое Copy-on-Write и почему `fork()` быстрый даже для процесса с 10 ГБ памяти
- Зачем `vfork()` существует, если есть COW (историческая причина и когда он до сих пор полезен)
- Как `clone()` связан с созданием потоков — какие флаги (CLONE_VM, CLONE_FILES, CLONE_FS) что разделяют
- Почему семейство `exec()` (execve, execvp, execl) не создаёт новый процесс, а заменяет текущий

Приведи пример, когда `fork()` без `exec()` имеет смысл — не учебный, а реальный (Redis, PostgreSQL, Apache).

---

## Задание 4. Практика: карта процессов твоей сессии

> **TL;DR:** по `pstree -sp $$` можно прочитать всю историю запуска
> текущей shell — кто через кого его породил. На проде такая карта
> объясняет, откуда «нежданные» процессы.

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

> **TL;DR:** у живого процесса fd видны в `/proc/PID/fd/`. Сокет
> выглядит как `socket:[N]`, pipe как `pipe:[N]`, файл — как символьная
> ссылка на путь. `lsof -p PID -i` отдельно показывает сетевые fd.

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

> **TL;DR:** сигнал — это асинхронное уведомление процессу. Ядро
> проверяет pending-маску при возврате в user-mode. Стандартные сигналы
> (1–31) — один бит (повтор теряется), realtime (34–64) — настоящая
> очередь + данные через `sigqueue()`.

### Теоретическая часть

Ответь на вопросы:

1. Как ядро доставляет сигнал процессу — в какой момент проверяется маска pending signals?
2. Почему стандартные сигналы (1–31) не образуют очередь, а realtime-сигналы (34–64) образуют? В чём практическая разница?
3. Что произойдёт, если послать SIGTERM процессу в D-state (uninterruptible sleep)?
4. Объясни разницу между `signal()` и `sigaction()` в C (или `trap` в bash).

### Практика 1: worker.sh — обработка нескольких сигналов

Напиши скрипт `worker.sh` (готовый — в `solutions/worker.sh`):

- при **SIGTERM** → graceful shutdown: напечатать сообщение, удалить
  lock-файл `/tmp/worker.lock`, выйти
- при **SIGINT** → игнорировать
- при **SIGUSR1** → напечатать число итераций и uptime
- основной цикл: каждые 2 секунды `echo "Working..."`, при старте
  создаёт lock-файл

Тест:

```bash
./worker.sh &
PID=$!
sleep 3

kill -USR1 $PID   # ↓ должно появиться «iterations=N uptime=Ns»
sleep 1
kill -INT  $PID   # ↓ должно быть проигнорировано (worker продолжает)
sleep 2
kill -TERM $PID   # ↓ graceful: удаляет lock и выходит
wait $PID 2>/dev/null

ls /tmp/worker.lock 2>&1  # "No such file" — lock удалён
```

Затем повтори, но убей `kill -9`:

```bash
./worker.sh & PID=$!; sleep 2
kill -9 $PID
wait $PID 2>/dev/null
ls /tmp/worker.lock   # файл остался!
rm -f /tmp/worker.lock
```

**Почему после `kill -9` lock остался?** SIGKILL не доставляется
процессу — ядро просто выкидывает его из runqueue. Trap не отрабатывает.

### Практика 2: pkill, killall — групповое убийство

```bash
# Запусти несколько одинаковых процессов
sleep 500 &
sleep 500 &
sleep 500 &
jobs
# [1]   Running  sleep 500 &
# [2]-  Running  sleep 500 &
# [3]+  Running  sleep 500 &

# kill -l — посмотреть все сигналы и их номера
kill -l | head -5

# pkill по имени (SIGTERM по умолчанию)
pkill -TERM sleep
jobs   # все три убиты

# pkill можно сузить фильтрами: -f (по cmdline), -u (по юзеру), -P (по PPID)
sleep 500 & ; pkill -P $$ sleep   # убить только детей этого shell

# killall — то же по точному имени
sleep 500 & ; killall sleep
wait 2>/dev/null
```

> **Осторожно:** `pkill ssh` на проде убьёт все ssh-сессии, включая
> твою. Всегда сужай через `-u` или `-P`, и лучше сначала `pgrep` для
> проверки, кого затронет.

### Практика 3: sigqueue — realtime-сигнал с данными

Стандартный `kill(2)` шлёт только номер сигнала. `sigqueue(2)` шлёт
номер + 32-битное значение, и **десять таких подряд доставятся все**
(в отличие от обычных — те сливаются в один).

**Отправитель** — `sigqueue_demo.c`:

```c
#define _POSIX_C_SOURCE 200809L
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 3) { fprintf(stderr, "usage: %s <pid> <int>\n", argv[0]); return 1; }
    pid_t pid = atoi(argv[1]);
    union sigval sv = { .sival_int = atoi(argv[2]) };
    if (sigqueue(pid, SIGRTMIN, sv) == -1) { perror("sigqueue"); return 1; }
    return 0;
}
```

**Получатель** — `receiver.c`:

```c
#define _POSIX_C_SOURCE 200809L
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

static volatile int got = 0;
static volatile int last = 0;

static void handler(int sig, siginfo_t *info, void *ctx) {
    (void)sig; (void)ctx;
    got++;
    last = info->si_value.sival_int;   // ← данные от sigqueue!
}

int main(void) {
    struct sigaction sa = {0};
    sa.sa_sigaction = handler;
    sa.sa_flags = SA_SIGINFO;           // ← обязательно для realtime
    sigaction(SIGRTMIN, &sa, NULL);

    printf("receiver pid=%d\n", getpid());
    fflush(stdout);
    for (int i = 0; i < 15; i++) {
        sleep(1);
        if (got) printf("got=%d last=%d\n", got, last), fflush(stdout);
    }
    return 0;
}
```

Эксперимент:

```bash
gcc sigqueue_demo.c -o sigqueue_demo
gcc receiver.c     -o receiver

./receiver &
RPID=$!
sleep 1

# Шлём 10 realtime-сигналов подряд, быстро
for i in $(seq 1 10); do ./sigqueue_demo $RPID $i; done
sleep 2

# Ожидаем: got=10 (все доставлены!)
# Если бы это был обычный kill -USR1 — got был бы 1 (сигналы сливаются)
wait $RPID 2>/dev/null
```

**Вопросы:**

1. Почему `pkill sleep` иногда убивает лишние процессы? Как сузить через `-f`, `-u`, `-P`?
2. Чем `sigqueue(2)` отличается от `kill(2)`? Что позволяет передать?
3. Почему для realtime-сигналов (SIGRTMIN..SIGRTMAX) обязательно нужен `SA_SIGINFO`?
4. Запусти receiver, но шли ему `kill -USR1 $RPID` в цикле 10 раз. Сколько получит?

**Почитать:**
- [pkill(1)](https://man7.org/linux/man-pages/man1/pkill.1.html)
- [sigqueue(3)](https://man7.org/linux/man-pages/man3/sigqueue.3.html)
- [signal-safety(7)](https://man7.org/linux/man-pages/man7/signal-safety.7.html)
- [rt_sigqueueinfo(2)](https://man7.org/linux/man-pages/man2/rt_sigqueueinfo.2.html)

---

## Задание 7. Практика + теория: удалённый файл и inode

> **TL;DR:** `rm` вызывает `unlink()` — убирает **имя** в директории.
> Файл реально освобождается только когда (а) имён = 0 **и** (б) открытых
> fd = 0. Отсюда классика «df 100%, du 50%»: logrotate удалил лог, но
> процесс держит fd → данные на диске, но невидимы.

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

> **TL;DR:** классический демон делает два `fork()` + `setsid()` чтобы
> отцепиться от терминала и сессии. В эпоху systemd это не нужно:
> `Type=simple` и systemd сам всё правильно запустит. Double-fork ещё
> встречается в старом коде (nginx, sshd, cron).

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

**Дополнительно (необязательно):** в репозитории лежит готовый пример
double-fork демона — `../../daemon/simpled.c` (относительно этой лабы).
Собери и запусти из каталога репозитория:

```bash
# Из корня lern/process/:
gcc daemon/simpled.c -o /tmp/simpled
sudo /tmp/simpled
ps -ef | grep simpled          # PPID=1, TTY=?
sudo tail -f /var/log/simpled.log
# Завершить:
sudo pkill -x simpled
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

> **TL;DR:** `/proc` — это не файлы на диске, а **живой API к ядру**.
> `cat /proc/PID/status` — это вызов функции ядра, которая
> на-лету форматирует данные из `task_struct`. Размер всегда 0.

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

> **TL;DR:** зомби — процесс умер, родитель не сделал `wait()`. Сирота
> — процесс жив, родитель умер (его усыновит init). Зомби занимают
> только слот в таблице процессов — много зомби = исчерпание pid_max.

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
# Найди зомби (колонка STAT = "Z"):
ps aux | awk '$8 ~ /Z/'
# Ожидаемо: 5 строк вида
#   user   12345  0.0  ...  Z+  [python3] <defunct>

# Попробуй kill -9 на зомби:
kill -9 <ZOMBIE_PID>
ps aux | awk '$8 ~ /Z/'   # всё ещё здесь — SIGKILL не действует на мёртвых

# Убей родителя:
kill <PARENT_PID>
sleep 1
ps aux | awk '$8 ~ /Z/'   # зомби исчезли: init усыновил и сделал wait()
```

Объясни цепочку: убийство родителя → зомби становятся сиротами → init усыновляет → init вызывает wait() → записи удалены.

---

## Задание 11. Практика + теория: nohup, disown, tmux — сравнение через fd

> **TL;DR:** разные способы «отвязать» процесс от терминала работают
> **по-разному**: `nohup` ставит SIG_IGN на SIGHUP + перенаправляет fd;
> `disown` убирает из job-table (bash не шлёт SIGHUP); `tmux` поднимает
> отдельную сессию с собственным pty. Посмотрим разницу через `/proc`.

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

> **TL;DR:** лимит fd проверяется на трёх уровнях: per-process
> (`ulimit -n`), per-user (`limits.conf`), system-wide (`fs.file-max`).
> Сработает самый узкий. На проде узким обычно оказывается per-process
> — для nginx/postgres его надо поднимать в systemd unit.

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
# Ожидаемо:
#   Упёрлись в лимит!
#   Последний успешный fd: ~253
#   Всего открыто: ~250
#   Ошибка: [Errno 24] Too many open files: '/dev/null'
```

Какой номер fd был последним? Совпадает ли с `ulimit -n` и почему может не совпадать?
(Подсказка: fd 0, 1, 2 уже заняты; python сам открывает ещё 2–3 для импорта модулей.)

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

> **TL;DR:** контрольная. `lab_helper.sh` запускает 4 процесса с
> намеренными проблемами (fd leak, зомби-фарм, CPU-spin, deleted file).
> Найди все 4 **не читая код** — только `ps`, `/proc`, `lsof`, `strace`.
> Ответы — в `answers.md`, но не подглядывай.

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

## Задание 14. Практика + теория: strace, lsof, gdb, ptrace

> **TL;DR:** когда процесс завис — `strace -p PID` покажет, на каком
> syscall он застрял. Когда нужен стек или значения переменных —
> `gdb -p PID`. Когда нужно посмотреть, что он держит открытым —
> `lsof -p PID`. Все три инструмента используют один механизм —
> `ptrace(2)`.

### Теоретическая часть

Ответь на вопросы:

1. Что такое системный вызов и чем он отличается от вызова библиотечной функции?
2. Как `strace` перехватывает syscalls (ptrace API)? Что делают
   `PTRACE_ATTACH`, `PTRACE_SYSCALL`, `PTRACE_DETACH`?
3. Почему `strace` замедляет процесс в 10–100 раз?
4. Чем `strace -e trace=network` отличается от `strace -e trace=file`?
5. Чем `gdb -p <pid>` отличается от `strace -p <pid>` — оба используют ptrace,
   но дают разную информацию. В каких случаях какой инструмент выбрать?
6. Почему к одному процессу одновременно может быть прикреплён только
   один трассировщик? (Подсказка: ядро хранит `task->parent` для ptrace.)
7. Что такое `/proc/sys/kernel/yama/ptrace_scope` и зачем нужен?

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

**Упражнение E: lsof — кто что держит**

```bash
# Все TCP-сокеты, слушающие порт
sudo lsof -iTCP -sTCP:LISTEN -P -n

# Какие процессы держат удалённые файлы (deleted)
sudo lsof +L1

# Что открыто конкретным процессом
sudo lsof -p $(pgrep -f ssh-agent | head -1) 2>/dev/null

# Кто пишет в /var/log
sudo lsof /var/log/syslog
```

**Упражнение F: gdb — присоединение к живому процессу**

Зачем: `strace` показывает syscalls, но **не** внутренний state. `gdb`
умеет прочитать стек, регистры, переменные, и даже **вызвать функцию**
в работающем процессе (починка без рестарта).

```bash
sudo apt install -y gdb

# Шаг 1: запустить долгий процесс
sleep 600 &
PID=$!

# Шаг 2: прикрепиться, посмотреть что там внутри, отцепиться
sudo gdb -p $PID -batch \
    -ex 'info proc' \
    -ex 'info threads' \
    -ex 'bt' \
    -ex 'detach'
# В выводе увидишь:
#   process PID <sleep>
#   — список потоков (для sleep — один)
#   — backtrace: застряли внутри nanosleep() / clock_nanosleep()

kill $PID
wait $PID 2>/dev/null
```

**Трюк: закрыть fd в живом процессе без рестарта**

```bash
# Откроем «лишний» fd 9 в нашем shell:
exec 9</dev/null
ls -la /proc/$$/fd/9      # l-wx------ ... -> /dev/null

# Вызовем close(9) прямо в этом shell из gdb:
sudo gdb -p $$ -batch -ex 'call (int)close(9)' -ex 'detach' 2>&1 | tail -3

ls -la /proc/$$/fd/9 2>&1 # "No such file" — fd закрыт!
```

Это реальный приём на проде: если приложение течёт fd и нельзя
рестартить — можно закрыть ненужные через gdb.

> **Если `gdb -p` падает с «Operation not permitted»:** проверь
> `cat /proc/sys/kernel/yama/ptrace_scope`. По умолчанию в Ubuntu — `1`
> (только потомки). Варианты:
> - запускать gdb под `sudo` (обычно работает);
> - временно разрешить: `sudo sysctl kernel.yama.ptrace_scope=0`;
> - постоянно: правка `/etc/sysctl.d/10-ptrace.conf`.

**Упражнение G: ptrace — пишем мини-strace в 30 строк**

Чтобы понять, как strace работает изнутри: форкаем ребёнка, он объявляет
себя трассируемым (`PTRACE_TRACEME`), делает `exec`. Родитель в цикле
будит ребёнка до следующего syscall-entry/exit и считает остановки —
это и есть число syscalls × 2.

```c
// mini_strace.c — считает syscalls команды
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <cmd> [args...]\n", argv[0]); return 1; }

    pid_t pid = fork();
    if (pid == 0) {
        // РЕБЁНОК: объявляем себя трассируемым и exec-имся
        ptrace(PTRACE_TRACEME, 0, 0, 0);
        execvp(argv[1], &argv[1]);
        perror("execvp");
        return 1;
    }

    // РОДИТЕЛЬ: ждём первой остановки (после execve)
    int status;
    waitpid(pid, &status, 0);

    // В цикле: продолжаем до следующего syscall-entry или syscall-exit
    long stops = 0;
    while (1) {
        if (ptrace(PTRACE_SYSCALL, pid, 0, 0) < 0) break;
        if (waitpid(pid, &status, 0) < 0)         break;
        if (WIFEXITED(status))                     break;
        stops++;
    }
    // Каждый syscall даёт 2 остановки (entry + exit)
    fprintf(stderr, "[mini_strace] syscalls: %ld\n", stops / 2);
    return 0;
}
```

```bash
gcc mini_strace.c -o mini_strace
./mini_strace /bin/ls /tmp > /dev/null
# stderr: [mini_strace] syscalls: 147
# (точное число зависит от glibc/ядра — для Ubuntu 24.04 обычно 140–160)

# Сравни с настоящим strace:
strace -c /bin/ls /tmp 2>&1 >/dev/null | tail -1
# 100.00    0.001205    8    148    18 total
#                             ^^^ — calls
```

Цифры должны примерно совпасть (отличие на 1–2 — из-за финального
`exit_group`, который наш цикл не считает, так как `WIFEXITED` возвращает
true и мы выходим до `stops++`).

**Почитать:**
- [ptrace(2)](https://man7.org/linux/man-pages/man2/ptrace.2.html)
- [gdb attach — GDB manual](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Attach.html)
- [How strace works — Julia Evans](https://jvns.ca/blog/2021/04/03/what-problems-do-people-solve-with-strace/)

---

## Задание 15. Теория + практика: межпроцессное взаимодействие (IPC)

> **TL;DR:** 6 основных механизмов. **pipe/FIFO** — односторонняя,
> байтовый поток. **UNIX socket** — двусторонний, быстрый,
> локально-файловые права. **POSIX mq** — очередь с приоритетом.
> **shared memory** — самый быстрый (0 копирований) но нужен
> собственный mutex. **signal** — не для данных, а для уведомлений.
> **TCP** — сеть или другая машина.

### Теоретическая часть

Ответь на вопросы:

1. Перечисли механизмы IPC в Linux и для каждого укажи: двунаправленный ли,
   работает ли между несвязанными процессами, сохраняется ли после перезагрузки:
   - anonymous pipe (`pipe(2)`)
   - named pipe / FIFO (`mkfifo(3)`)
   - UNIX domain socket (`AF_UNIX`)
   - TCP/UDP socket (`AF_INET`)
   - SysV message queue (`msgget(2)`)
   - POSIX message queue (`mq_open(3)`)
   - SysV / POSIX shared memory (`shmget`, `shm_open`)
   - signal + sigqueue
2. Почему `cmd1 | cmd2` использует anonymous pipe, а `mkfifo /tmp/p; cmd1 >/tmp/p &; cmd2 </tmp/p` — named pipe? Чем отличаются в жизненном цикле?
3. Что такое SIGPIPE и когда его получает пишущий? Почему сервер на
   TCP должен либо игнорировать его, либо использовать `MSG_NOSIGNAL`?
4. Когда выбрать UNIX-сокет, а когда TCP loopback? Разница в производительности
   и правах доступа.

### Практика А: anonymous pipe

```bash
# Простейший случай — shell делает это каждый раз, когда видит "|"
ps aux | grep -c bash

# Под капотом: strace покажет pipe2() + fork() + dup2()
strace -f -e trace=pipe2,dup2,fork,execve -- bash -c 'echo hi | cat' 2>&1 | tail -20
```

### Практика Б: named pipe (FIFO)

```bash
# Создать FIFO
mkfifo /tmp/myfifo
ls -la /tmp/myfifo   # тип "p" — именованный канал

# Терминал 1 — читатель (блокируется до появления писателя):
cat /tmp/myfifo &
READER=$!

# Терминал 2 — писатель:
echo "hello via FIFO" > /tmp/myfifo

wait $READER
rm /tmp/myfifo
```

Вопрос: что произойдёт, если писатель откроет FIFO, пока нет читателя?
(Подсказка: `open()` блокируется на O_WRONLY без O_NONBLOCK.)

### Практика В: UNIX domain socket

Сервер (`unix_server.py`):

```python
import socket, os
path = '/tmp/lab.sock'
try: os.unlink(path)
except FileNotFoundError: pass

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.bind(path)
s.listen(1)
print(f"listening on {path}")
conn, _ = s.accept()
print("client connected")
while True:
    data = conn.recv(1024)
    if not data: break
    conn.sendall(data.upper())
conn.close(); s.close(); os.unlink(path)
```

Клиент (`unix_client.py`):

```python
import socket
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('/tmp/lab.sock')
s.sendall(b'ping')
print(s.recv(1024))
s.close()
```

```bash
python3 unix_server.py &
sleep 0.5
python3 unix_client.py
# Ожидаемо:
#   b'PING'
wait

# Пока сервер жив, посмотреть сокет на ФС:
# $ ls -la /tmp/lab.sock
# srwxr-xr-x 1 user user 0 ... /tmp/lab.sock
# первая буква 's' — это сокет
```

Вопрос: проверь `ls -la /tmp/lab.sock` — кто может подключиться? Как
ограничить через `chmod 600`?

### Практика Г: POSIX message queue

```c
// mq_send.c — отправитель
#include <mqueue.h>
#include <fcntl.h>        // O_WRONLY, O_CREAT
#include <sys/stat.h>     // mode constants
#include <string.h>
#include <stdio.h>

int main(int argc, char **argv) {
    (void)argc;
    struct mq_attr attr = { .mq_maxmsg = 10, .mq_msgsize = 128 };
    mqd_t q = mq_open("/lab_mq", O_WRONLY | O_CREAT, 0600, &attr);
    if (q == (mqd_t)-1) { perror("mq_open"); return 1; }
    const char *msg = argv[1] ? argv[1] : "hello";
    if (mq_send(q, msg, strlen(msg) + 1, 0) == -1) { perror("mq_send"); return 1; }
    mq_close(q);
    return 0;
}
```

```c
// mq_recv.c — получатель
#include <mqueue.h>
#include <fcntl.h>        // O_RDONLY
#include <stdio.h>

int main(void) {
    mqd_t q = mq_open("/lab_mq", O_RDONLY);
    if (q == (mqd_t)-1) { perror("mq_open"); return 1; }
    char buf[128];
    unsigned prio;
    ssize_t n = mq_receive(q, buf, sizeof(buf), &prio);
    if (n < 0) { perror("mq_receive"); return 1; }
    printf("got: %s (prio=%u)\n", buf, prio);
    mq_close(q);
    mq_unlink("/lab_mq");
    return 0;
}
```

```bash
gcc mq_send.c -o mq_send -lrt
gcc mq_recv.c -o mq_recv -lrt

./mq_send "msg from A"
./mq_recv
# Ожидаемо:
#   got: msg from A (prio=0)

# POSIX MQ видна как файл в /dev/mqueue (ядро монтирует при загрузке)
./mq_send "will persist"
ls /dev/mqueue/ 2>/dev/null
# Ожидаемо: lab_mq — очередь жива, пока кто-нибудь её не прочитает (или reboot)
cat /dev/mqueue/lab_mq 2>/dev/null
# Ожидаемо (строка одна, числа могут отличаться):
#   QSIZE:13  NOTIFY:0  SIGNO:0  NOTIFY_PID:0
# QSIZE — сумма байт в очереди. У нас одно сообщение "will persist\0" = 13 байт.
./mq_recv   # забрал — очередь пропала
```

**Вопросы к практике:**

1. Чем `SOCK_STREAM` отличается от `SOCK_DGRAM` в UNIX-сокете?
2. Почему очереди сообщений имеют приоритет, а pipe — нет?
3. Какой механизм IPC выберешь для: (а) передачи одной команды между
   несвязанными процессами, (б) обмена 1 ГБ данных между процессами на
   одной машине, (в) IPC между двумя контейнерами на одном хосте?

**Почитать:**
- [pipe(7)](https://man7.org/linux/man-pages/man7/pipe.7.html)
- [fifo(7)](https://man7.org/linux/man-pages/man7/fifo.7.html)
- [unix(7)](https://man7.org/linux/man-pages/man7/unix.7.html)
- [mq_overview(7)](https://man7.org/linux/man-pages/man7/mq_overview.7.html)
- [Beej's Guide to IPC](https://beej.us/guide/bgipc/) *(англ., лучший вводный обзор)*

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
