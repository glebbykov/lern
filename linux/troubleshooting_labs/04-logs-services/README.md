# Урок 4: Логи и Сервисы (systemd)

## Цель
Починить сервис, который падает при запуске.

## Основные команды
- `systemctl status <service>` — текущее состояние сервиса и последние 10 строк лога.
- `systemctl start/stop/restart <service>` — управление сервисом.
- `journalctl -u <service>` — посмотреть ПОЛНЫЙ лог конкретного сервиса.
- `journalctl -xe` — посмотреть ошибки системы в самом конце лога (jump to end).
- `dmesg -T` — логи ядра (важно для поиска OOM-Killer или ошибок диска).
- `grep -i error /var/log/syslog` — классический поиск ошибок по текстовым файлам.

## Задание
1. Запустите `./simulate.sh`. Скрипт создаст "сломанный" сервис `broken-app.service` и попытается его запустить.
2. Проверьте статус: `systemctl status broken-app`. Вы увидите `failed`.
3. Посмотрите логи: `journalctl -u broken-app`. 
4. В логах вы найдете причину (например, сервис пытается прочитать несуществующий файл или ему не хватает прав).
5. Исправьте причину (создайте нужный файл или исправьте скрипт в `/etc/systemd/system/broken-app.service`), выполните `systemctl daemon-reload` и `systemctl start broken-app`.
