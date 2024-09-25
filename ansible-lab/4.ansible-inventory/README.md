
# Ansible Lab - Advanced Inventory Configuration

### Введение

Инвентарь (Inventory) в Ansible – это важнейшая составляющая работы с хостами. Он может быть статическим, динамическим, поддерживать группы и переменные. В этой лабораторной работе мы рассмотрим более сложные сценарии инвентаря, включая работу с двумя удалёнными хостами и локальным хостом.

### Структура инвентаря

Инвентарь может содержать как физические серверы, так и локальные машины. В этой лабораторной работе мы используем три хоста:
1. Удалённый веб-сервер (`host1`).
2. Удалённый сервер базы данных (`host2`).
3. Локальный хост (`localhost`).

Пример инвентаря:

```ini
[webservers]
host1 ansible_host=192.168.56.101 ansible_user=root

[dbservers]
host2 ansible_host=192.168.56.102 ansible_user=root

[local]
localhost ansible_connection=local ansible_user={{ ansible_user }}
```

В данном примере:
- `webservers` и `dbservers` — группы для удалённых серверов.
- `localhost` используется для выполнения задач на локальной машине.
- Переменная `ansible_connection=local` указывает, что подключение к `localhost` будет локальным.

### Задание 1: Настройка инвентаря с локальным хостом

Создайте файл `inventory.ini`, который содержит:
- Два удалённых сервера (веб-сервер и сервер базы данных).
- Локальный хост с подключением через локальную сессию.

Ваш файл должен выглядеть так:

```ini
[webservers]
host1 ansible_host=192.168.56.101 ansible_user=root

[dbservers]
host2 ansible_host=192.168.56.102 ansible_user=root

[local]
localhost ansible_connection=local ansible_user={{ ansible_user }}
```

### Задание 2: Глобальные переменные для всех хостов

Для сокращения дублирования кода мы можем задавать переменные для всех хостов в группе `all`:

```ini
[all:vars]
ansible_user=root
ansible_ssh_private_key_file=/path/to/private/key
```

Это означает, что все хосты будут использовать заданные переменные, если не указано иное.

### Задание 3: Работа с плейбуком

Теперь создадим плейбук, который выполняет следующие задачи:
1. Устанавливает веб-сервер Nginx на удалённом веб-сервере `host1`.
2. Устанавливает базу данных MySQL на сервере `host2`.
3. Печатает информацию о системе на локальном хосте.

Пример плейбука:

```yaml
---
- name: Install and configure web server
  hosts: webservers
  become: true
  tasks:
    - name: Install Nginx
      package:
        name: nginx
        state: present

- name: Install and configure database server
  hosts: dbservers
  become: true
  tasks:
    - name: Install MySQL
      package:
        name: mysql-server
        state: present

- name: Gather system information
  hosts: local
  tasks:
    - name: Print system information
      command: uname -a
      register: system_info

    - debug:
        var: system_info.stdout
```

### Задание 4: Использование групп внутри групп

Ansible позволяет использовать вложенные группы. Например, вы можете создать группу `production`, включающую обе группы (`webservers` и `dbservers`):

```ini
[webservers]
host1 ansible_host=192.168.56.101

[dbservers]
host2 ansible_host=192.168.56.102

[production:children]
webservers
dbservers
```

Теперь, используя группу `production`, вы можете запускать команды на всех серверах:

```bash
ansible all -i inventory.ini -m ping
```

### Задание 5: Динамическое управление локальными и удалёнными задачами

Добавим в плейбук задачи, которые будут выполняться как на локальном хосте, так и на удалённых серверах. Например:

1. На локальном хосте мы будем выводить список установленных пакетов.
2. На веб-сервере — веб-приложение.
3. На базе данных — подготовить базу данных.

Пример расширенного плейбука:

```yaml
---
- name: Install and configure web server
  hosts: webservers
  become: true
  tasks:
    - name: Install Nginx
      package:
        name: nginx
        state: present

    - name: Deploy web application
      copy:
        src: /path/to/app
        dest: /var/www/html
      notify: Restart Nginx

- name: Install and configure database server
  hosts: dbservers
  become: true
  tasks:
    - name: Install MySQL
      package:
        name: mysql-server
        state: present

    - name: Prepare database
      mysql_db:
        name: myapp_db
        state: present

- name: List installed packages on local host
  hosts: local
  become: true
  tasks:
    - name: List installed packages
      command: dpkg --list
      register: packages_list

    - debug:
        var: packages_list.stdout
```

### Задание 6: Проверка конфигурации

Теперь, используя созданный инвентарь и плейбук, запустите следующие проверки:
1. Проверьте инвентарь с помощью команды `ansible-inventory`.
2. Выполните плейбук и убедитесь, что задачи выполняются как на удалённых, так и на локальном хосте.

```bash
ansible-inventory -i inventory.ini --list
ansible-playbook -i inventory.ini playbook.yml
```

### Вопросы:

1. **Какие различия в использовании `localhost` и удалённых хостов в Ansible?**
2. **Какие преимущества использования глобальных переменных для всех хостов?**
3. **В чем заключается преимущество динамических инвентарей и когда они необходимы?**

### Дополнительные задания:

1. **Добавьте проверку доступности сервисов на всех серверах с помощью модуля `uri` (например, проверку доступности веб-сайта).**
2. **Настройте плейбук, который будет создавать резервные копии баз данных на сервере базы данных (`host2`) и сохранять их на локальном хосте.**
3. **Используйте Ansible для настройки мониторинга серверов на локальном хосте с помощью `netstat` и сохранения результатов в файл на локальной машине.**

### Заключение

В этой лабораторной работе вы изучили сложные аспекты работы с инвентарем Ansible, включая работу с локальными и удалёнными хостами, использование глобальных переменных и выполнение различных задач на серверах.
