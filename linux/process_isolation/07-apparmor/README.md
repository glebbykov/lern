# 07 — AppArmor: мандатный контроль доступа

## Идея

DAC (Discretionary Access Control) — обычные права rwx, владелец
файла может их менять. **MAC** (Mandatory Access Control) — права
заданы системным администратором через профили, программа не может
их изменить, **даже работая от root**.

В Linux два MAC:
- **AppArmor** — path-based, профиль привязан к пути исполняемого
  файла. Используется в Ubuntu/Debian/SUSE. Простой синтаксис.
- **SELinux** — label-based, у каждого файла, процесса, порта своя
  «метка» (`user_u:role_r:type_t:level`). Используется в RHEL/Fedora.
  Гибче, но сложнее.

## Режимы профиля

- **enforce** — нарушения блокируются и логируются.
- **complain** — нарушения только логируются (для разработки).
- **disabled** — профиль выгружен из ядра.

## Что делаем

1. Пишем профиль для `/usr/local/bin/secret-reader.sh`, который
   запрещает чтение `/etc/passwd` и запись куда-либо кроме `/tmp`.
2. Загружаем в ядро через `apparmor_parser -r`.
3. Запускаем скрипт от root — попытка `cat /etc/passwd` падает с
   `Permission denied`, несмотря на uid 0.
4. Переводим профиль в complain-mode — теперь только логи.
5. Смотрим `aa-status`, `dmesg | grep DENIED`.
6. Снимаем профиль.

## Запуск

```bash
sudo ./run.sh
sudo ./check.sh
```

## Где не сработает

- WSL2 (AppArmor обычно не загружен).
- Голый Docker без `--privileged` (LSM hook на хосте).
- Хосты с SELinux вместо AppArmor (RHEL/Fedora).

Проверка: `cat /sys/kernel/security/apparmor/profiles 2>/dev/null` —
должно что-то быть.

## Карта в Docker

Docker по умолчанию вешает на каждый контейнер профиль
`docker-default` (`/etc/apparmor.d/docker`). Кастомный:
```
docker run --security-opt apparmor=my-profile-name ...
```
Профиль должен быть предварительно загружен в ядро на хосте — внутри
контейнера `apparmor_parser` не работает (нужен `CAP_MAC_ADMIN`,
который дропнут).
