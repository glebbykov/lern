
# Лабораторная работа 8 (Часть 2): Теги, Вывод изменений в файлах, Проверка синтаксиса и другие техники

## Введение
В этой части лабораторной работы мы рассмотрим использование тегов для управления задачами в Ansible, проверку синтаксиса перед запуском плейбуков, вывод изменений в файлах, а также другие полезные методы для отладки и улучшения процесса работы с Ansible.

## Основные практические задания

### Задание 1: Использование тегов

1. Напишите плейбук Ansible, который будет выполнять несколько задач, таких как установка пакетов, копирование файлов и перезапуск службы.
2. Добавьте теги к каждой задаче. Например:
   ```yaml
   - name: Установить пакеты
     apt:
       name:
         - nginx
         - git
       state: present
     tags: 
       - install

   - name: Копировать конфигурационный файл
     copy:
       src: ./nginx.conf
       dest: /etc/nginx/nginx.conf
     tags:
       - config

   - name: Перезапустить Nginx
     service:
       name: nginx
       state: restarted
     tags:
       - restart
   ```
3. Выполните плейбук с использованием флага `--tags`, чтобы запустить только задачи с определенными тегами:
   ```bash
   ansible-playbook playbook.yml --tags install
   ```

### Задание 2: Вывод изменений в файлах

1. Напишите плейбук, который будет копировать шаблон конфигурационного файла на удаленный хост с использованием модуля `template`.
2. Используйте флаг `--diff`, чтобы увидеть, какие изменения были внесены в файлы:
   ```bash
   ansible-playbook playbook.yml --diff
   ```
3. Проанализируйте вывод и сравните до и после применения изменений.

### Задание 3: Проверка синтаксиса

1. Напишите плейбук с простыми задачами (например, установка пакетов или изменение конфигураций).
2. Используйте флаг `--syntax-check`, чтобы проверить синтаксис плейбука перед выполнением:
   ```bash
   ansible-playbook playbook.yml --syntax-check
   ```
3. Исправьте любые ошибки, если они возникнут, и снова выполните проверку.

### Задание 4: Проверка сценария без изменений (Dry Run)

1. Напишите плейбук, который выполняет изменения на удалённом хосте, такие как установка пакетов или создание новых файлов.
2. Выполните сценарий в режиме проверки, используя флаг `--check`, чтобы увидеть, что будет изменено, но без реального внесения изменений:
   ```bash
   ansible-playbook playbook.yml --check
   ```
3. Оцените результат и убедитесь, что изменения будут безопасными перед их реальным применением.

## Дополнительные задания

### Задание 5: Применение нескольких тегов и пропуск задач

1. Измените предыдущий плейбук и добавьте несколько тегов к каждой задаче.
2. Запустите плейбук с использованием нескольких тегов через флаг `--tags`, а также с флагом `--skip-tags`, чтобы исключить выполнение определённых задач:
   ```bash
   ansible-playbook playbook.yml --tags "install,restart" --skip-tags config
   ```

### Задание 6: Тестирование изменений на ограниченном наборе хостов

1. Напишите плейбук для управления несколькими хостами.
2. Используйте флаг `--limit`, чтобы применить плейбук только к одному из хостов для тестирования:
   ```bash
   ansible-playbook playbook.yml --limit web
   ```

### Задание 7: Модули для работы с файлами

1. Напишите плейбук, который будет использовать модули `lineinfile`, `copy`, и `file` для управления файлами на удаленном хосте.
2. Выполните плейбук и проанализируйте изменения с использованием флага `--diff`.

## Вопросы для самопроверки

1. Как работает флаг `--diff` и зачем его использовать?
2. В каких случаях полезно использовать теги и как они помогают управлять задачами?
3. Чем отличается режим проверки (dry run) от реального выполнения плейбука?
4. Как можно ограничить выполнение плейбука на конкретных хостах или группах хостов?

## Заключение

Использование тегов, проверка синтаксиса, вывод изменений в файлах и режим dry run — это мощные инструменты для управления сценариями и отладки в Ansible. Эти техники позволяют упростить процесс разработки плейбуков и снизить риск ошибок при их выполнении.
