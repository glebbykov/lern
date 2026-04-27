# 06 — Seccomp: фильтрация системных вызовов

## Идея

Seccomp (Secure Computing Mode) — механизм ядра, ограничивающий
*какие* syscalls процесс может делать. Запрещённый syscall → ядро
шлёт `SIGSYS` → процесс падает с core dump (или возвращает `EPERM`,
если фильтр так настроен).

Два режима:

1. **Strict** (`SECCOMP_MODE_STRICT`) — разрешены только 4 syscalls:
   `read`, `write`, `_exit`, `sigreturn`. Используется в SECCOMP-bpf
   почти никогда (слишком жёстко).
2. **Filter** (`SECCOMP_MODE_FILTER`) — программа на BPF (Berkeley
   Packet Filter), решает разрешать/блокировать каждый syscall.
   Это и есть «seccomp-bpf», который использует Docker.

## Способы применить

| Способ | Когда уместно |
|---|---|
| `prctl(PR_SET_SECCOMP, MODE_FILTER, &prog)` | C-код, runc, Chrome |
| `libseccomp` | удобный API над prctl |
| `systemd-run -p SystemCallFilter=...` | быстрый ad-hoc запуск |
| Docker `--security-opt seccomp=profile.json` | контейнеры |

## Что делаем

1. **systemd-run путь**: `systemd-run --wait -p SystemCallFilter=~uname uname -a`
   → процесс получит SIGSYS на `uname()`.
2. **systemd-run с группой**: `~@privileged` — запретит весь класс
   привилегированных вызовов (mount, ptrace, и т.д.).
3. **Сырой seccomp-bpf через Python ctypes**: пишем минимальную
   BPF-программу, ставим через `prctl`, проверяем что нужный syscall
   стреляет SIGSYS.

## Запуск

```bash
sudo ./run.sh
sudo ./check.sh
```

## Карта в Docker

`docker run` без `--security-opt` использует `default seccomp profile`
из `moby/profiles/seccomp/default.json` — это белый список ~310 syscalls
из ~440 существующих. Блокирует `kexec_load`, `clock_settime`,
`reboot`, и т.п.

`--security-opt seccomp=unconfined` снимает фильтр (плохая идея).
`--security-opt seccomp=my.json` — кастомный.
