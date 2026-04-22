# Этап 4 — практический «взлом»

Запускается на живом контейнере stage3. Для каждой атаки печатаем
`✓ blocked` или `✗ FAIL`. В конце — сумма.

Что пытаемся:

| # | Действие | Что должно остановить |
|---|---|---|
| 1 | `touch /pwned.txt` | `read_only: true` |
| 2 | `echo x > /app/pwned` | `read_only: true` |
| 3 | `touch /tmp/ok` | (должно пройти — это tmpfs) |
| 4 | `chown root:root /tmp/ok` | `cap_drop: ALL` (CAP_CHOWN) |
| 5 | `socket(SOCK_RAW, ICMP)` | `cap_drop: ALL` (CAP_NET_RAW) |
| 6 | `mknod /tmp/disk b 8 0` | `cap_drop: ALL` (CAP_MKNOD) |
| 7 | `mount -t tmpfs none /mnt` | `cap_drop: ALL` (CAP_SYS_ADMIN) |
| 8 | `date -s ...` | `cap_drop: ALL` (CAP_SYS_TIME) |
| 9 | `read /dev/kmsg` | `cap_drop: ALL` (CAP_SYSLOG) |
| 10 | `chmod u+s /bin/ls` | `read_only` + `no-new-privileges` |

> Почему не `ping` и не `bind 127.0.0.1:80`: современный Docker
> выставляет в namespace контейнера `net.ipv4.ping_group_range=0 0`
> и `net.ipv4.ip_unprivileged_port_start=0`, так что эти действия
> больше не зависят от capabilities и как индикатор защиты не годятся.

Запуск:

```bash
./run.sh
```
