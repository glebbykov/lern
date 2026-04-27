# 04 — cgroups v2: лимиты ресурсов

## Идея

Namespaces изолируют *видимость* ресурсов; cgroups ограничивают
*потребление*. Это два независимых механизма — Docker использует оба.

В **cgroups v2** (с ядра 4.5, по умолчанию с 5.8) одна унифицированная
иерархия. Один процесс находится ровно в одной cgroup-папке, для
которой явно включены контроллеры ресурсов через `cgroup.subtree_control`.

Точка монтирования: `/sys/fs/cgroup` (тип `cgroup2`).

## Контроллеры, которые трогаем

| Контроллер | Файл лимита | Что делает |
|---|---|---|
| memory | `memory.max` | хард-лимит RAM, при превышении OOM-kill |
| cpu | `cpu.max` | `<квота> <период>` микросекунд |
| pids | `pids.max` | макс число процессов в cgroup |
| io | `io.max` | `<MAJ:MIN> rbps=... wbps=... riops=... wiops=...` |

Бонус — **PSI** (Pressure Stall Information): `memory.pressure`,
`cpu.pressure`, `io.pressure`. Показывает *сколько % времени cgroup
ждала* нужный ресурс.

## Что делаем

1. **Memory**: cgroup с `memory.max=64M`, запускаем `stress-ng --vm 1
   --vm-bytes 256M` — ловим OOM-kill, читаем `memory.events`.
2. **CPU**: cgroup с `cpu.max="20000 100000"` (20% одного ядра),
   запускаем busy-loop, замеряем `top` — увидим throttling.
3. **PIDs**: `pids.max=10`, делаем fork-bomb на 50 процессов —
   `EAGAIN` после 10-го.
4. **IO** (опционально, требует fio): `io.max wbps=1048576` для
   корневого диска, замер скорости записи.

## Запуск

```bash
sudo ./run.sh    # последовательно демонстрирует все 4 контроллера
sudo ./check.sh  # автотест: фактический OOM, throttle, fork-block
```

## Карта в Docker

| Здесь | docker run |
|---|---|
| `echo 64M > memory.max` | `--memory=64m` |
| `echo "20000 100000" > cpu.max` | `--cpus=0.2` |
| `echo 10 > pids.max` | `--pids-limit=10` |
| `io.max ... wbps=1048576` | `--device-write-bps /dev/sda:1mb` |
