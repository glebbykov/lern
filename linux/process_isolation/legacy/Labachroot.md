
---

## 0. Среда, риски и подготовка

**Зачем:** `chroot` не является границей безопасности. С root‑правами и доступом к `/proc` можно выйти к корню хоста через `/proc/1/root`. Делайте работу **на тестовой ВМ**.

**Требования (Debian/Ubuntu):**

```bash
sudo apt update && sudo apt install -y busybox-static procps util-linux strace vim
```

* `busybox-static` — статически слинкованный бинарник, позволит собрать минимальный rootfs без зависимостей.
* `procps` — `ps` и др. утилиты для наблюдения процессов.
* `util-linux` — `unshare`, `mount` и прочие базовые инструменты.
* `strace` — наблюдение системных вызовов (`chroot(2)`).
* `vim` — правка конфигов (по требованию: **используем ****`vim`****, не \*\*\*\*`nano`**).

**Переменные окружения и каталоги:**

```bash
export ROOT=/lab/chroot/rootfs
sudo mkdir -p "$ROOT"
```

---

## 1. Теория: что делает `chroot`

* `chroot(2)` меняет **root directory** процесса — точку, откуда VFS начинает путь `/`. После этого все абсолютные пути резолвятся относительно нового корня.
* `chroot` **не изолирует** PID‑пространство, сеть, IPC, hostname (UTS), пользователей и cgroups. Это **операционная изоляция файловой системы**, а не sandbox.
* Типичный приём — после `chroot` выполнить `chdir("/")` (инструменты `chroot(1)` делают это за нас).
* В отличие от `pivot_root(2)` `chroot` не меняет само дерево монтирования процесса — только точку отсчёта путей.

Практические последствия: внутри простого `chroot` вы видите процессы/hostname/сеть хоста.

---

## 2. Сборка минимального rootfs (BusyBox static)

**Почему так:** статический BusyBox работает без динамических либ; минимальный и надёжный старт.

Создадим структуру каталогов и откроем `tmp` как общедоступный:

```bash
sudo install -d -m 0755 "$ROOT"/{bin,sbin,etc,proc,sys,dev,usr/bin,usr/sbin,root,tmp,var/{log,run,lib},home}
sudo chmod 1777 "$ROOT"/tmp
```

Скопируем BusyBox и создадим аплеты‑ссылки:

```bash
sudo cp /bin/busybox "$ROOT"/bin/
cd "$ROOT"/bin
sudo ln -s busybox sh
sudo ln -s busybox ash
sudo ln -s busybox ls
sudo ln -s busybox cat
sudo ln -s busybox echo
sudo ln -s busybox ps
sudo ln -s busybox mount
sudo ln -s busybox uname
sudo ln -s busybox vi
```

Базовые файлы в `/etc`:

```bash
sudo vim "$ROOT"/etc/passwd
```

Вставьте:

```
root:x:0:0:root:/root:/bin/sh
```

```bash
sudo vim "$ROOT"/etc/group
```

```
root:x:0:
```

```bash
sudo vim "$ROOT"/etc/hostname
```

```
chroot-lab
```

```bash
sudo vim "$ROOT"/etc/hosts
```

```
127.0.0.1   localhost
127.0.1.1   chroot-lab
```

*(Опционально для DNS внутри chroot — если нужны сетевые утилиты):*

```bash
sudo cp /etc/resolv.conf "$ROOT"/etc/resolv.conf
```

**Обоснование:** многие программы ожидают базовые записи о пользователях/группах и hostname; `resolv.conf` нужен для резолвинга имён.

---

## 3. Подключаем псевдо‑ФС внутрь rootfs (dev/proc/sys)

**Почему так:**

* `/dev` — устройства (`/dev/null`, tty и др.) — без них часть программ не стартует.
* `/proc`, `/sys` — интерфейсы ядра, нужны, чтобы `ps`, `mount`, `ip` и пр. корректно работали.

Монтируем с безопасной пропагацией:

```bash
sudo mount --rbind /dev  "$ROOT"/dev
sudo mount --make-rslave "$ROOT"/dev
sudo mount -t proc  proc  "$ROOT"/proc
sudo mount -t sysfs sys   "$ROOT"/sys
```

**Почему ****`--make-rslave`****:** события монтирования с хоста видны внутри, но обратной пропагации из chroot наружу не будет — безопаснее для эксперимента.

Проверка:

```bash
mount | egrep "$ROOT/(dev|proc|sys)"
```

---

## 4. Вход в `chroot` и проверка границ изоляции

```bash
sudo chroot "$ROOT" /bin/sh
```

Проверим и интерпретируем:

```sh
echo "Inside PID: $$"      # PID процесса внутри хоста (не 1) — PID общий
ps                           # Видны процессы хоста — нет PID‑изоляции
cat /etc/hostname            # chroot-lab (файл в новом корне)
hostname                     # hostname хоста — UTS общий
cat /proc/self/mountinfo | head -n 10  # дерево монтирования хоста с подмонтированными /dev,/proc,/sys
cat /proc/net/dev            # те же сетевые интерфейсы — NET общий
```

Проверка связи с FS:

```sh
mkdir -p /root && echo "hello from chroot" > /root/inside
exit
sudo cat "$ROOT"/root/inside  # файл действительно в каталоге rootfs на хосте
```

---

## 5. Почему `chroot` не безопасен (демонстрация побега)

**Идея:** обладая root‑правами и доступом к `/proc`, процесс внутри простого `chroot` может переключить корень файловой системы на корень процесса PID 1 (инит системы хоста), доступный по пути `/proc/1/root`. Это возможно, потому что `chroot` не меняет **mount‑namespace**: путь `/proc/1/root` по‑прежнему ссылается на **реальный корень хоста**.

### Предпосылки (что должно быть верно прежде)

* Вы находитесь **внутри** `chroot` из предыдущих шагов и обладаете **реальными** root‑правами (UID 0, без user‑namespace).

Если нет введите:

```bash
sudo chroot "$ROOT" /bin/sh
```

* Внутри смонтирован `/proc` (мы монтировали его на шаге 3).

### Шаги демонстрации

1. Убедимся, что `/proc/1/root` указывает на корень хоста:

```sh
readlink -f /proc/1/root   # ожидаемо: /
ls -ld / /proc/1/root       # должны выглядеть как два корня одной FS
```

2. Посмотрим содержимое корня PID 1 (то есть корня хоста), не покидая chroot:

```sh
ls /proc/1/root | head
```

3. Выполним «побег»: сменим корень процесса на корень PID 1 и откроем оболочку:

```bash
chroot /proc/1/root /bin/sh
```

4. Проверим, что мы теперь действительно в окружении хоста:

```sh
pwd                        # /
hostname                   # вернёт hostname хоста, а не chroot-lab
cat /etc/hostname          # совпадает с выводом hostname
cat /proc/self/mountinfo | head -n 5  # дерево маунтов хоста
```

### Почему это работает

* `/proc/<pid>/root` — это «магическая» символическая ссылка на **корневой каталог процесса `<pid>`** в его mount‑namespace.
* Так как обычный `chroot` **не создаёт новый mount‑namespace**, ссылка `/proc/1/root` ведёт в корень **хостовой** FS.
* Команда `chroot /proc/1/root /bin/sh` (требует `CAP_SYS_CHROOT`) просто меняет root directory текущего процесса на корень хоста и исполняет `/bin/sh` уже **в корне хоста**.

### Как сделать, чтобы «побег» не сработал (контр‑эксперименты)

1. **Лишить доступа к `/proc`** внутри chroot (нет пути к `/proc/1/root`):

```sh
umount /proc || true
chroot /proc/1/root /bin/sh || echo "no /proc → нет побега"
```

2. **Запустить chroot под непривилегированным пользователем** (нет `CAP_SYS_CHROOT`):

```sh
exit  # если вы в сессии из шага 3
sudo chroot --userspec=65534:65534 "$ROOT" /bin/sh -c 'chroot /proc/1/root /bin/sh' || echo "EPERM: нет прав на chroot"
```

3. **Создать user‑namespace** с `unshare --user --map-root-user` (root станет «поддельным», capabilities будут namespaced и не действуют на хост): попытка `chroot /proc/1/root` также не даст доступа к корню хоста.

### Наблюдение через `strace`

Посмотрим сам системный вызов `chroot(2)` во время «побега»:

```bash
sudo strace -e chroot chroot "$ROOT" /bin/sh -c 'chroot /proc/1/root /bin/sh -c "echo HOST:\ $(hostname)"'
# В выводе увидите: chroot("/proc/1/root") = 0
```

**Вывод:** простой `chroot` не обеспечивает безопасности. При наличии root‑прав и `/proc` корень хоста остаётся достижимым через `/proc/1/root`. Именно поэтому «чистый» `chroot` применяют только как операционный приём, а для изоляции используют **namespaces** и **cgroups**.# Лабораторная работа: **chroot** и изоляция процессов — актуальная версия (без развилок)

> Цель: на практике показать, **что именно изолирует ****`chroot`**** (только файловую систему)**, и как дополнять его **namespaces** (PID/UTS/MNT) и **cgroups v2** для получения контейнероподобной среды. Все шаги линейные, без альтернатив. Каждый шаг снабжён теоретическим обоснованием «почему так» и проверками.

---

## 6. Запуск внутри ****`df -h`**** chroot под непривилегированным пользователем

**Зачем:** уменьшить последствия ошибок/экспериментов.

```bash
sudo chroot --userspec=65534:65534 "$ROOT" /bin/sh
id                        # uid=65534(nobody)
hostname chroot-lab-2     # EPERM — прав на смену hostname нет
exit
```

---

## 7. Добавляем namespaces: PID/UTS/MNT через `unshare`

**Теория:** `unshare` создаёт новые пространства имён. Нам нужны PID (своё дерево процессов), UTS (свой hostname), MNT (своё дерево монтирования). Чтобы `ps` видел только процессы внутри, нужно подмонтировать **новый** `proc`.

**Команда (без вариантов):**

```bash
sudo unshare --pid --uts --mount --fork \
  --mount-proc="$ROOT/proc" \
  chroot "$ROOT" /bin/sh
```

Проверим эффект:

```sh
echo "PID inside: $$"   # 1 — вы init нового PID‑namespace
hostname chroot-ns
hostname                # chroot-ns — теперь UTS изолирован
ps                      # видны только процессы внутри ns
cat /proc/1/cgroup      # проверим привязку процесса к cgroup
```

Ожидаемо минимальный `ps` вида:

```
PID   USER     COMMAND
    1 root     sh
    7 root     ps
```

---

## 8. Лимиты ресурсов через cgroups v2 (через `systemd-run`)

**Теория:** cgroups v2 управляет лимитами CPU/памяти/IO. `systemd-run` создаёт временный unit и помещает наш процесс в отдельный cgroup с заданными лимитами.

**Запуск с лимитами 256МБ RAM и 25% CPU:**

```bash
sudo systemd-run -p MemoryMax=256M -p CPUQuota=25% -t \
  chroot "$ROOT" /bin/sh
```

**Почему далее нужен маунт cgroup2 внутри chroot:** мы смонтировали `sysfs`, но не отдельную FS cgroup2. Чтобы прочитать лимиты, её надо примонтировать.

**Примонтируем cgroup2 и читаем лимиты:**

```sh
mount -t cgroup2 none /sys/fs/cgroup
# убедимся, что это именно cgroup2 поверх /sys/fs/cgroup
grep ' cgroup2 ' /proc/self/mountinfo | grep '/sys/fs/cgroup'
# получим свой путь в дереве cgroups v2
CG=$(cut -d: -f3 /proc/self/cgroup)
# проверим лимиты:
cat "/sys/fs/cgroup${CG}/memory.max"   # ~268435456
cat "/sys/fs/cgroup${CG}/cpu.max"      # формат: quota period, напр. 25000 100000
exit
```

**Интерпретация:** `memory.max` — байты или `max`; `cpu.max` — квота и период (`25000/100000` ≈ 25%).

**Проверка с хоста:**

```bash
# systemd при запуске вывел имя юнита, например: run-u21.service
systemctl show run-u21.service -p MemoryMax -p CPUQuota -p CPUWeight
```

---

## 9. Наблюдение системных вызовов `chroot`

**Зачем:** увидеть реальный вызов `chroot(2)` в действии.

```bash
sudo strace -e chroot chroot "$ROOT" /bin/sh -c 'echo ok'
# ожидаем в выводе: chroot("$ROOT") = 0
```

---

## 10. Приборка

```bash
# Выйдите из всех шеллов/chroot.
sudo umount -l "$ROOT"/proc  || true
sudo umount -l "$ROOT"/sys   || true
sudo umount -l "$ROOT"/dev   || true
sudo rm -rf  "${ROOT%/rootfs}"
```

**Почему порядок важен:** занятые маунты не снимутся; `-l` выполнит «ленивое» размонтирование после освобождения дескрипторов.

---

## 11. Частые ошибки и их причины

1. `ps` в `unshare` видит процессы хоста — вы читаете старый `/proc`. Всегда используйте `--mount-proc="$ROOT/proc"` при запуске.
2. `hostname` не меняется в простом `chroot` — нужен UTS‑namespace (делаем через `unshare`).
3. `Operation not permitted` на действиях с сетью/монтированиями — не хватает capabilities; внутри user‑ns они ограничены.
4. `chroot: failed to run '/bin/sh': No such file or directory` — отсутствует интерпретатор/либы. Решение: статический BusyBox (как здесь).
5. Нет `/dev/null` и др. устройств — пропущен bind‑mount `/dev`.

---

## 12. Итог

* `chroot` изолирует **только файловую систему**.
* Для контейнероподобной изоляции добавляйте namespaces (`unshare --pid --uts --mount --fork --mount-proc=…`).
* Для лимитов ресурсов используйте cgroups v2 (в примере через `systemd-run`).
* Root внутри `chroot` не даёт безопасности; доступ к `/proc` открывает путь к корню хоста.
