# Увеличение размера swap до 50GB

## Шаг 1: Удаление существующего swap

1. Отключите текущий swap файл:
    ```bash
    sudo swapoff /swapfile
    ```
2. Удалите текущий swap файл:
    ```bash
    sudo rm /swapfile
    ```

## Шаг 2: Создание нового файла подкачки размером 50GB

1. Создайте новый файл подкачки размером 50GB с помощью `fallocate`:
    ```bash
    sudo fallocate -l 50G /swapfile
    ```
   Если `fallocate` недоступен, используйте `dd`:
    ```bash
    sudo dd if=/dev/zero of=/swapfile bs=1M count=51200
    ```

2. Установите правильные права доступа для файла подкачки:
    ```bash
    sudo chmod 600 /swapfile
    ```

3. Инициализируйте файл как swap:
    ```bash
    sudo mkswap /swapfile
    ```

4. Включите файл подкачки:
    ```bash
    sudo swapon /swapfile
    ```

5. Проверьте статус swap:
    ```bash
    sudo swapon --show
    ```

## Шаг 3: Автоматическое подключение swap при загрузке системы

1. Добавьте запись в `/etc/fstab` для автоматического подключения swap при загрузке системы:
    ```bash
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    ```

## Пример вывода команды `free -m` после настройки

```bash
free -m
               total        used        free      shared  buff/cache   available
Mem:            3928         373        3575           0         188        3554
Swap:          51200           0       51200
