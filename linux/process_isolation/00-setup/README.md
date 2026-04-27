# 00 — Setup и проверка окружения

Перед прохождением курса убедимся что хост готов:

- ядро **>= 5.10** (нужно для cgroups v2 и time namespace)
- cgroups v2 unified hierarchy примонтирована в `/sys/fs/cgroup`
- AppArmor загружен в ядре (для этапа 07)
- user namespaces включены (`kernel.unprivileged_userns_clone=1`)
- установлены утилиты: `unshare`, `nsenter`, `ip netns`, `setcap`,
  `apparmor_parser`, `systemd-nspawn`, `debootstrap`, `stress-ng`,
  `busybox-static`

## Запуск

```bash
sudo ./check.sh    # покажет что есть/нет и почему важно
sudo ./install.sh  # доустановит пакеты (Ubuntu/Debian)
sudo ./check.sh    # перепроверит
```

## Где это не сработает

- **WSL2**: ядро есть, но AppArmor скорее всего выключен. Этап 07 пропусти.
- **Голый Docker без --privileged**: вложенные namespaces, cgroups
  и mount работать не будут. Используй настоящую ВМ.
- **macOS / Windows host**: тут не пройдёт совсем — нужен Linux kernel.
