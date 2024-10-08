
# Лабораторная работа 7: Дебаг сценариев Ansible

## Введение
Ошибки неизбежны при написании и выполнении сценариев Ansible. В этой лабораторной работе мы рассмотрим способы отладки сценариев Ansible, включая получение подробных сообщений об ошибках, использование режима отладки, проверку соединений SSH и другие техники для обнаружения проблем в сценариях.

## Основные практические задания

### Задание 1: Информативные сообщения об ошибках
1. Напишите простой плейбук Ansible, который будет устанавливать пакет `git` на удалённый хост.
2. Используйте плагин `debug`, чтобы выводить более удобочитаемые сообщения об ошибках. Для этого добавьте следующее в файл `ansible.cfg`:
    ```ini
    [defaults]
    stdout_callback = debug
    ```
3. Выполните плейбук и проанализируйте вывод сообщений об ошибках (если такие возникнут). Проверьте, что сообщения стали более понятными.

### Задание 2: Отладка ошибок с SSH-подключением
1. Настройте удалённый хост с отключённым SSH-доступом. Затем попробуйте выполнить команду:
    ```bash
    ansible all -m ping
    ```
2. Используйте флаг `-vvv`, чтобы получить подробную информацию о том, почему Ansible не может подключиться:
    ```bash
    ansible all -vvv -m ping
    ```
3. Устраните проблему с подключением и снова запустите команду для проверки.

### Задание 3: Использование модуля debug
1. Напишите плейбук, который будет выполнять проверку свободного места на диске на удалённом хосте, используя модуль `shell`.
2. Добавьте задачу с использованием модуля `debug`, чтобы вывести результат команды на экран:
    ```yaml
    - name: Проверить свободное место на диске
      shell: df -h /
      register: disk_space

    - name: Вывести результат
      debug:
        var: disk_space.stdout
    ```

### Задание 4: Модуль assert
1. Напишите плейбук, который проверяет наличие определённого сетевого интерфейса на удалённом хосте (например, `eth0`), используя модуль `assert`.
2. Если интерфейс не существует, сценарий должен завершиться с ошибкой:
    ```yaml
    - name: Проверить наличие интерфейса eth0
      assert:
        that:
          - ansible_eth0 is defined
    ```

## Дополнительные задания

### Задание 5: Использование интерактивного отладчика
1. Напишите плейбук для установки веб-сервера Nginx на удалённый хост.
2. Включите интерактивный отладчик для первой задачи плейбука:
    ```yaml
    debugger: always
    ```
3. Выполните плейбук и по шагам выполните каждую задачу с использованием команд отладчика (например, `p`, `u`, `c`).

### Задание 6: Режим проверки (Dry Run)
1. Напишите плейбук для создания нового пользователя на удалённом хосте.
2. Выполните сценарий в режиме проверки (dry run):
    ```bash
    ansible-playbook --check playbook.yml
    ```
3. Оцените, как повлияют изменения, и проверьте успешность выполнения команд без реального изменения хоста.

### Задание 7: Отладка переменных окружения
1. Создайте плейбук, который выполняет команду `printenv` на удалённом хосте и сохраняет результат.
2. Используйте модуль `debug` для вывода конкретной переменной окружения (например, `PATH`):
    ```yaml
    - name: Выполнить printenv
      shell: printenv
      register: env_vars

    - name: Вывести переменную PATH
      debug:
        msg: "Переменная PATH: {{ env_vars.stdout_lines | select('search', '^PATH=') }}"
    ```

## Дополнительные вопросы для самопроверки
1. Какие ключевые моменты следует учитывать при отладке сценариев Ansible?
2. В каких случаях имеет смысл использовать интерактивный отладчик?
3. Какую роль играет флаг `-vvv` в процессе отладки?
4. Какие существуют методы для проверки синтаксиса сценария до его выполнения?
5. Какие инструменты предоставляет Ansible для проверки состояния хостов перед выполнением плейбуков?
6. Почему важно использовать режим проверки (dry run) перед применением изменений?

## Заключение
Использование инструментов отладки Ansible позволяет быстрее находить и исправлять ошибки в сценариях, улучшая процесс разработки и развертывания. Практикуйтесь в использовании флагов отладки, режимов проверки и интерактивных отладчиков, чтобы улучшить свои навыки.
