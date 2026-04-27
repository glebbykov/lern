# 03 — pivot_root: безопасная смена корня

## Идея

`chroot` уязвим (этап 01 — побег через `/proc/1/root`). Все настоящие
рантаймы (`runc`, `crun`, `LXC`, `systemd-nspawn`) используют
`pivot_root(2)` внутри отдельного mount namespace.

`pivot_root(new, put_old)`:
1. Делает `new` корнем процесса.
2. Старый корень монтируется в `put_old` (внутри `new`).
3. Это позволяет затем отмонтировать `put_old` — и старый корень
   **исчезает из дерева монтирования**, недостижим вообще никак.

После такого `/proc/1/root` ведёт уже в новый корень — побега нет.

## Требования

- Новый корень должен быть на ОТДЕЛЬНОЙ файловой системе
  (или быть mount point) — иначе `EBUSY`.
- Должны быть в новом mount-namespace (`unshare --mount`), иначе
  pivot_root повлияет на хост.

## Что делаем

1. `unshare --mount --pid --fork` — отдельный mnt + pid ns.
2. Монтируем `tmpfs` в `/lab/03/newroot` (это и будет «отдельная ФС»).
3. Копируем туда минимальный rootfs.
4. `pivot_root . put_old` → текущий корень становится новым.
5. Размонтируем `put_old` — старый корень исчезает.
6. Пробуем тот же побег `chroot /proc/1/root` — теперь ведёт в нас же.

## Запуск

```bash
sudo ./run.sh
sudo ./check.sh
```

## Карта в Docker

`runc` для каждого контейнера делает примерно:
```
clone(CLONE_NEWNS|CLONE_NEWPID|CLONE_NEWUTS|...)
mount(merged_dir, merged_dir, MS_BIND)   # чтобы стало mount point
pivot_root(merged_dir, merged_dir/.old)
umount2(".old", MNT_DETACH)
```
Это шаги 2-5 нашего скрипта, дословно.
