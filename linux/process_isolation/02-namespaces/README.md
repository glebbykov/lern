# 02 — Namespaces: 6 видов изоляции

## Идея

Namespace = «отдельный экземпляр глобального ресурса ядра». Linux
поддерживает 8 типов; нам достаточно знать 6 ключевых:

| Namespace | Что изолирует | Создаётся флагом `unshare` |
|---|---|---|
| **UTS** | hostname, domain | `-u` / `--uts` |
| **PID** | таблица PID, PID 1 | `-p --fork` |
| **MNT** | дерево mount | `-m` / `--mount` |
| **NET** | интерфейсы, маршруты, iptables, сокеты | `-n` / `--net` |
| **USER** | UID/GID mapping | `-U` / `--user` |
| **IPC** | SysV IPC, POSIX message queues | `-i` / `--ipc` |
| **CGROUP** | вид иерархии cgroups | `-C` / `--cgroup` |
| **TIME** | `CLOCK_MONOTONIC`, `CLOCK_BOOTTIME` (kernel >= 5.6) | `-T` / `--time` |

`docker run` поднимает разом UTS, PID, MNT, NET, IPC, CGROUP — и опционально USER.

## Что делаем

Поднимаем каждый namespace отдельно, наблюдаем эффект. Для каждого:
- сравниваем inode `/proc/self/ns/<TYPE>` снаружи и внутри
  (если разные — мы реально в новом ns);
- показываем что внутри изменилось (hostname, PID, mount, IP-интерфейсы,
  uid mapping, semget).

Финал: одной командой создаём процесс, изолированный по всем шести.

## Запуск

```bash
sudo ./run.sh
sudo ./check.sh
```

## Карта в Docker

`docker run --rm alpine sh` =

```
unshare --uts --pid --mount --net --ipc --cgroup --fork \
  --mount-proc \
  /lab/01/rootfs/bin/sh
```

Плюс заранее:
- сетевой namespace соединяется veth-парой с bridge `docker0` (этап 09),
- mount-ns делает `pivot_root` в overlay-merged каталог (этап 03 + 08),
- cgroup лимиты применяются (этап 04).

USER namespace в Docker не включён по умолчанию — это компромисс между
безопасностью и совместимостью.
