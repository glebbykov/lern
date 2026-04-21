# Лабораторная работа 4: Виртуальные сети и нативные контейнеры Linux

## Цель работы
Разобраться с тем, как контейнеры объединяются в сети и получают доступ наружу. Познакомиться с `systemd-nspawn` — нативным инструментом Linux для запуска контейнеров уровня операционной системы.

## Теоретические сведения
До сих пор мы создавали изолированные сетевые пространства имен (`ip netns`), но они были пустыми — у них не было связи с внешним миром. 
Контейнерные движки (Docker, Podman) используют два ключевых виртуальных устройства ядра:
1.  **Veth (Virtual Ethernet)** — виртуальный сетевой кабель. Состоит из двух концов: пакет, отправленный в один конец, мгновенно появляется в другом. Позволяет "проткнуть" границу между двумя Network Namespaces.
2.  **Bridge (Сетевой мост / Коммутатор)** — программный коммутатор (свитч). К нему можно подключить множество veth-кабелей, чтобы контейнеры могли общаться друг с другом.

---

## Часть 1: Виртуальный патч-корд (Veth Pair)

Соединим два изолированных сетевых пространства напрямую, как если бы мы связали два компьютера одним сетевым кабелем.

### Практическое задание 1
1. Создайте два сетевых пространства:
   ```bash
   ip netns add alpha
   ip netns add beta
   ```
2. Создайте виртуальный кабель (veth пару):
   ```bash
   ip link add veth-alpha type veth peer name veth-beta
   ```
3. "Раздайте" концы кабеля по пространствам:
   ```bash
   ip link set veth-alpha netns alpha
   ip link set veth-beta netns beta
   ```
4. Назначьте им IP-адреса и поднимите интерфейсы:
   ```bash
   ip netns exec alpha ip addr add 10.0.0.1/24 dev veth-alpha
   ip netns exec alpha ip link set veth-alpha up
   ip netns exec alpha ip link set lo up

   ip netns exec beta ip addr add 10.0.0.2/24 dev veth-beta
   ip netns exec beta ip link set veth-beta up
   ip netns exec beta ip link set lo up
   ```
5. Проверьте связь (из пространства `alpha` пингуем пространство `beta`):
   ```bash
   ip netns exec alpha ping -c 3 10.0.0.2
   ```

---

## Часть 2: Виртуальный коммутатор (Linux Bridge)

Связывать контейнеры парами неудобно. Создадим центральный коммутатор, к которому будут подключаться все контейнеры (аналог сети `docker0`).

### Практическое задание 2
1. Создайте сетевой мост на хост-машине:
   ```bash
   ip link add my-bridge type bridge
   ip link set my-bridge up
   # Даем мосту IP-адрес (он будет работать как шлюз по умолчанию)
   ip addr add 10.1.1.254/24 dev my-bridge
   ```
2. Создайте новое пространство `gamma` и кабель для него:
   ```bash
   ip netns add gamma
   ip link add veth-gamma type veth peer name veth-br
   ```
3. Один конец отдайте пространству `gamma`, а второй воткните в коммутатор `my-bridge`:
   ```bash
   ip link set veth-gamma netns gamma
   ip link set veth-br master my-bridge
   ip link set veth-br up
   ```
4. Настройте сеть внутри `gamma`:
   ```bash
   ip netns exec gamma ip addr add 10.1.1.1/24 dev veth-gamma
   ip netns exec gamma ip link set veth-gamma up
   ```
5. Проверьте пинг до моста (шлюза):
   ```bash
   ip netns exec gamma ping -c 2 10.1.1.254
   ```

---

## Часть 3: Нативные контейнеры (systemd-nspawn)

Использовать `unshare` для запуска изолированной системы долго и неудобно. В состав Systemd входит утилита `systemd-nspawn`, которая автоматически собирает все namespaces, монтирует `proc`, `sys` и применяет нужные лимиты.

### Практическое задание 3
1. Подготовим минимальную корневую систему (rootfs) дистрибутива Alpine Linux (весит всего ~3 Мегабайта):
   ```bash
   mkdir -p /tmp/alpine_rootfs
   cd /tmp/alpine_rootfs
   curl -o alpine.tar.gz -sL https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.1-x86_64.tar.gz
   tar xf alpine.tar.gz
   rm alpine.tar.gz
   ```
2. Запустим полноценный контейнер одной командой. `systemd-nspawn` сам поймет, что нужно изолировать корень, создать PID namespace и т.д.:
   ```bash
   systemd-nspawn -D /tmp/alpine_rootfs /bin/sh
   ```
3. Находясь внутри контейнера, проверьте:
   ```bash
   cat /etc/os-release
   ps aux  # Обратите внимание, что PID 1 - это /bin/sh
   exit
   ```

---

## Контрольные вопросы
1. В чем разница между `veth` и `bridge`?
2. Почему мы добавляли IP-адрес на `my-bridge` (хост-машину)? Зачем он нужен контейнерам?
3. Какие преимущества имеет `systemd-nspawn` перед ручным запуском `unshare` и `chroot`?

## Самостоятельная работа: Объединение сети и контейнера
Команда `systemd-nspawn` умеет автоматически создавать `veth` кабель и подключать его к мосту. 
Используйте флаг `--network-bridge=my-bridge` (мост должен существовать, мы создали его в Части 2), чтобы запустить наш Alpine-контейнер с изоляцией сети.

Выполните команду внутри контейнера:
```bash
ip addr
```
*Заметьте, что `systemd-nspawn` автоматически создал интерфейс `host0`. Сравните это поведение с тем, как мы делали это вручную в Части 2.*