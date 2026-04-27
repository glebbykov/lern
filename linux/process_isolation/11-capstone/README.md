# 11 — Capstone: «свой docker run» из ~150 строк bash

## Идея

Собираем всё, что прошли, в один скрипт `mycontainer.sh`, который
делает примерно `docker run --rm -it alpine sh` — но на голых
примитивах ядра.

## Что делает `mycontainer.sh`

| Шаг | Из какого этапа |
|---|---|
| Качает alpine rootfs (если нет) | 10 |
| Делает overlay: `lower=alpine, upper=container-id-rw` | 08 |
| Создаёт cgroup с лимитами `memory.max=128M`, `cpu.max=50%`, `pids.max=64` | 04 |
| `unshare --mount --pid --uts --net --ipc --fork --mount-proc` | 02 |
| `pivot_root` в overlay merged | 03 |
| Дропает все capabilities кроме `CAP_NET_BIND_SERVICE` | 05 |
| Применяет seccomp-bpf фильтр (блокирует `clock_settime`, `mount`) | 06 |
| (Если есть AppArmor) переключается в профиль `mycontainer-default` | 07 |
| (Опционально) поднимает veth + bridge, даёт IP | 09 |
| `exec` указанной команды | — |
| По завершении — чистит cgroup, размонтирует overlay | — |

## Запуск

```bash
sudo ./mycontainer.sh run alpine /bin/sh
sudo ./mycontainer.sh run alpine -- sh -c 'id; hostname; ls /; ps; ip a'
```

И сравнение с docker (если установлен):

```bash
sudo ./mycontainer.sh run alpine sh
docker run --rm -it alpine sh
# в обоих ты увидишь uid=0 root, hostname контейнерный, PID 1
```

## Запуск автотестов

```bash
sudo ./check.sh   # проверяет все 8 изоляций по очереди
```

## Что осталось «не как у Docker»

Чтобы не выходить за разумный объём capstone, опущено:
- сетевая часть (без `--net`) — контейнер использует netns хоста;
  включается флагом `--net`, но настройка iptables NAT остаётся
  на пользователя.
- registry / image distribution — только локальный alpine rootfs.
- multi-image build — строим из одного rootfs.
- логи в journald — пишем в stderr.

То есть `mycontainer` это не замена Docker, а **доказательство, что
Docker не магия**. ~150 строк bash, ~10 системных вызовов.
