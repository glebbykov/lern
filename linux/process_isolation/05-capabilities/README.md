# 05 — Linux Capabilities: дробление root

## Идея

`root` (uid 0) исторически = бог системы. С ядра 2.2 разработана
система **capabilities** — root разбит на ~40 отдельных привилегий.
Можно дать программе ровно одну (например, открыть порт <1024) без
полного root.

## Какие бывают

| Capability | Что разрешает |
|---|---|
| `CAP_NET_BIND_SERVICE` | bind на порт <1024 |
| `CAP_NET_RAW` | SOCK_RAW (ping, tcpdump) |
| `CAP_NET_ADMIN` | iptables, ip route, изменение интерфейсов |
| `CAP_SYS_ADMIN` | mount, swapon, namespaces (mega-cap, ~ root) |
| `CAP_SYS_TIME` | settimeofday, RTC |
| `CAP_DAC_OVERRIDE` | обход прав DAC (rwx) |
| `CAP_CHOWN` | chown на чужие файлы |
| `CAP_KILL` | сигналы чужим процессам |

Полный список: `man 7 capabilities`.

## Где живут capabilities

У процесса (`/proc/<pid>/status` → `CapEff/CapPrm/CapInh`) и у файла
(file capabilities — `getcap`/`setcap`, хранятся в xattr `security.capability`).

При `execve` ядро вычисляет новые caps процесса по формуле:
```
P'(perm) = (P(inh) & F(inh)) | (F(perm) & cap_bset)
```

## Что делаем

1. Копируем интерпретатор Python в `/tmp/pyweb`.
2. От `nobody` пробуем bind на 8080 — работает; на 80 — Permission denied.
3. `setcap cap_net_bind_service+ep /tmp/pyweb` → теперь bind 80 от nobody работает.
4. Снимаем cap (`setcap -r`) — снова не работает.
5. Бонус: смотрим `capsh --print` своего шелла, считаем декодированные caps.

## Запуск

```bash
sudo ./run.sh
sudo ./check.sh
```

## Карта в Docker

| Здесь | docker run |
|---|---|
| `setcap cap_net_bind_service+ep` | `--cap-add NET_BIND_SERVICE` |
| `setcap -r` | `--cap-drop NET_BIND_SERVICE` |
| `setcap cap_*=` (snim ALL) | `--cap-drop ALL` |

В Docker контейнер по умолчанию имеет 14 caps из ~40, остальные дропнуты.
Полное обнуление через `cap_drop: [ALL]` — то, что мы делали в
`docker-lab/07-security/hardening-lab/stage3`.
