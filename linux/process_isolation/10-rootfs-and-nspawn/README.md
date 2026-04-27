# 10 — Сборка rootfs и `systemd-nspawn`

## Идея

К этому моменту мы умеем всё, чтобы собрать контейнер руками. Не
хватает одного — нормального rootfs (не минимального busybox, а
полноценного дистрибутива). Два пути:

1. **Готовый minirootfs**: alpine публикует tarball на ~3 MB.
   `curl + tar -x` — и rootfs готов.
2. **debootstrap**: сборка Debian/Ubuntu rootfs с нуля. Скачивает
   базовые пакеты из официального репо, ставит их в указанную папку.

Затем — `systemd-nspawn`, нативный «container runtime» в systemd.
Он автоматически делает то, что мы 9 этапов разбирали: namespaces,
mount /proc, /sys, cgroup, базовая сеть. Удобно.

## Что делаем

1. Качаем alpine minirootfs в `/lab/10/alpine`.
2. (Опционально) `debootstrap minbase jammy /lab/10/ubuntu`.
3. Запускаем alpine через `systemd-nspawn -D /lab/10/alpine /bin/sh`.
4. Внутри проверяем: PID 1 = sh, hostname изолирован, /etc/os-release
   = alpine.
5. Запускаем тот же rootfs c сетью через bridge:
   `systemd-nspawn --network-bridge=lab-br -D /lab/10/alpine /bin/sh`.

## Запуск

```bash
sudo ./run.sh    # alpine + nspawn (debootstrap пропускается, он медленный)
WITH_DEBOOTSTRAP=1 sudo ./run.sh   # включает сборку Ubuntu rootfs (~2 мин)
sudo ./check.sh
```

## Карта в Docker

| Здесь | Docker |
|---|---|
| `curl alpine-minirootfs.tar.gz; tar xf` | `docker pull alpine` |
| `systemd-nspawn -D rootfs /bin/sh` | `docker run -it alpine sh` |
| `--network-bridge=lab-br` | `--network=bridge` |
| `debootstrap` | `docker build` слой `FROM debian:base` |

`systemd-nspawn` интересен тем, что он **не Docker-совместимый
runtime**, но использует те же примитивы ядра. Это «третий путь»
между ручным `unshare` и Docker.
