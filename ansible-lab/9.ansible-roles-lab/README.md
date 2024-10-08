
# Лабораторная работа №9: Масштабирование сценариев Ansible с использованием ролей

## Цель работы
Научиться использовать роли в Ansible для масштабирования и структурирования сценариев. Рассмотреть подходы к горизонтальному и вертикальному масштабированию задач.

## Задачи
1. Изучить базовую структуру ролей Ansible.
2. Разделить сценарий на роли для упрощения управления конфигурацией.
3. Использовать роли для автоматизации настройки нескольких типов серверов.

## Описание работы

### 1. Базовая структура роли
Роль в Ansible — это набор задач, переменных, шаблонов и файлов, которые можно легко переиспользовать. Основная структура директории роли:

- **tasks/**: основной файл с задачами (обычно `main.yml`).
- **handlers/**: определяет действия, которые должны выполняться при изменениях.
- **templates/**: содержит Jinja2-шаблоны для генерации конфигураций.
- **files/**: файлы, которые необходимо скопировать на удалённые хосты.
- **vars/**: переменные, специфичные для данной роли.
- **defaults/**: переменные по умолчанию, которые могут быть переопределены.
- **meta/**: метаданные роли, включая её зависимости.

### 2. Пример использования ролей

Создайте две роли для настройки веб-сервера (например, Nginx) и базы данных (PostgreSQL). Пример структуры:

```
roles/
  └── webserver/
      ├── tasks/
      │   └── main.yml
      ├── handlers/
      │   └── main.yml
      ├── templates/
      │   └── nginx.conf.j2
      └── vars/
          └── main.yml
  └── database/
      ├── tasks/
      │   └── main.yml
      └── templates/
          └── postgresql.conf.j2
```

#### Пример сценария

```yaml
---
- name: Настройка серверов
  hosts: all
  roles:
    - role: webserver
      listen_port: 80
    - role: database
      db_name: "mydb"
```

### 3. Масштабирование сценариев с ролями

Использование ролей позволяет разделить задачи на логические блоки и выполнять их на разных серверах или в рамках одной машины. Пример с развертыванием веб-сервера на одном хосте и базы данных на другом:

```yaml
---
- name: Настройка базы данных
  hosts: db
  roles:
    - role: database
      db_name: "mydb"

- name: Настройка веб-сервера
  hosts: web
  roles:
    - role: webserver
      listen_port: 80
```

### 4. Дебаг сценариев

Для отладки Ansible предоставляет несколько полезных опций:

- **-vvv**: детализированный вывод для анализа выполнения задач.
- **--check**: проверка сценария без внесения изменений на сервер.
- **--step**: пошаговое выполнение сценария.

Пример запуска сценария с отладкой:

```bash
ansible-playbook playbook.yml -vvv --step
```

### 5. Практическое задание

1. Создайте роли для настройки веб-сервера и базы данных.
2. Напишите сценарий для развертывания Nginx и PostgreSQL на разных хостах с использованием ролей.
3. Выполните сценарий с флагом `-vvv` и проанализируйте вывод.
4. Проверьте сценарий с флагом `--check` и проанализируйте возможные изменения.

### Вопросы для самопроверки

1. В чём отличие переменных в директориях `vars` и `defaults` роли?
2. Как передать переменные в роли через сценарий?
3. Какую роль выполняет секция `handlers` в структуре роли?
4. Какие параметры можно использовать для отладки сценариев Ansible?
