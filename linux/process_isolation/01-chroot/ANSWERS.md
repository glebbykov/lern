# 01 — chroot: контрольные вопросы

**В чём разница между `chroot` и `Mount Namespace`?**
`chroot` меняет только корневой каталог процесса (точку отсчёта путей).
Mount namespace изолирует *всю иерархию монтирования* — внутри можно
безопасно `mount`/`umount`, и это не повлияет на хост. Чистый chroot
не даёт такой свободы и виден через `/proc/<pid>/mountinfo` хоста.

**Почему через `/proc/1/root` можно сбежать из chroot?**
`/proc/<pid>/root` — magic-symlink ядра на корневой каталог процесса в
его mount namespace. Так как обычный chroot не создаёт нового
mount-ns, эта ссылка указывает на корень **хоста**. Имея root внутри
chroot и доступ к `/proc`, достаточно `chroot /proc/1/root /bin/sh`.

**Как защититься?**
1. Не давать root внутри chroot (запуск `--userspec=nobody`).
2. Не монтировать `/proc` внутрь.
3. Использовать `unshare --mount` + `pivot_root` (этап 03) — после
   `pivot_root` `/proc/1/root` ведёт уже в новый корень, и побег
   становится невозможен.

**Зачем монтируем `/dev`, `/proc`, `/sys`?**
- `/dev` — без `/dev/null`, `/dev/tty` многие программы падают на старте.
- `/proc` — нужен для `ps`, `top`, чтения `/proc/self/*` (многие либы
  читают `/proc/cpuinfo`, `/proc/meminfo`).
- `/sys` — для cgroups, информации о hardware.
