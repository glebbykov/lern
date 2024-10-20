
# Лабораторная работа Ansible 1 - Настройка простого веб-сервера

### Страницы 56-66

В этом примере мы настроим удалённый сервер для запуска простого веб-сервера с использованием Nginx. Сначала посмотрим, как работает сценарий `webservers.yml`, а затем рассмотрим его детали и улучшения.

#### Пример: webservers.yml
```yaml
---
- name: Настройка веб-сервера с Nginx
  hosts: webservers
  become: True
  tasks:
    - name: Убедиться, что Nginx установлен
      package:
        name: nginx
        update_cache: yes

    - name: Копировать конфигурационный файл Nginx
      copy:
        src: nginx.conf
        dest: /etc/nginx/sites-available/default

    - name: Включить конфигурацию
      file:
        src: /etc/nginx/sites-available/default
        dest: /etc/nginx/sites-enabled/default
        state: link

    - name: Копировать файл index.html
      template:
        src: index.html.j2
        dest: /usr/share/nginx/html/index.html

    - name: Перезапустить Nginx
      service:
        name: nginx
        state: restarted
```

### Конфигурационный файл NGINX

Для выполнения сценария нужен дополнительный файл конфигурации NGINX. Этот файл изменяет стандартную конфигурацию для сервера, обслуживающего статичные файлы. Сохраните этот файл под именем `playbooks/files/nginx.conf`.

#### Пример: nginx.conf
```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;
    root /usr/share/nginx/html;
    index index.html index.htm;
    server_name localhost;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Создание простой веб-страницы

Теперь добавим простую веб-страницу. Ansible может генерировать HTML страницы с помощью шаблонов Jinja2. Сохраните этот шаблон в файле `playbooks/templates/index.html.j2`.

#### Пример: index.html.j2
```html
<html>
  <head>
    <title>Welcome to Ansible</title>
  </head>
  <body>
    <h1>Nginx is configured using Ansible</h1>
    <p>If you see this page, it means Ansible has successfully installed Nginx.</p>
    <p>Running on {{ inventory_hostname }}</p>
  </body>
</html>
```

### Создание группы веб-серверов

Для настройки группы веб-серверов создайте файл реестра `playbooks/inventory/vagrant.ini`. Добавьте сервер `testserver` в группу `webservers`.

#### Пример: playbooks/inventory/vagrant.ini
```ini
[webservers]
testserver ansible_port=2202

[webservers:vars]
ansible_user = vagrant
ansible_host = 127.0.0.1
ansible_private_key_file = .vagrant/machines/default/virtualbox/private_key
```

Проверьте, как группы настроены в инвентаре с помощью команды:

```bash
ansible-inventory --graph
```

### Запуск сценария

Запускайте сценарии с помощью команды `ansible-playbook`:

```bash
ansible-playbook webservers.yml
```

### Ожидаемый результат:

```bash
PLAY [Настройка веб-сервера с Nginx] **********************************************
TASK [Gathering Facts] **********************************************************
ok: [testserver]

TASK [Убедиться, что Nginx установлен] ******************************************
changed: [testserver]

TASK [Копировать конфигурационный файл Nginx] ***********************************
changed: [testserver]

TASK [Включить конфигурацию] ****************************************************
ok: [testserver]

TASK [Копировать файл index.html] ***********************************************
changed: [testserver]

TASK [Перезапустить Nginx] ******************************************************
changed: [testserver]

PLAY RECAP **********************************************************************
testserver              : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

После успешного выполнения сценария откройте веб-браузер и перейдите по адресу `http://localhost:8080`. Вы увидите страницу с сообщением, что Nginx был успешно установлен Ansible.
