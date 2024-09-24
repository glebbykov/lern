
# Ansible Lab - Configuring Nginx with TLS Support

### Страницы 72-83

### Введение

В этой лабораторной работе вы научитесь настраивать веб-сервер Nginx с поддержкой TLSv1.2 с помощью Ansible. Мы рассмотрим использование переменных, циклов, обработчиков, тестов и проверок.

### Задание 1: Создание сертификата TLS

Создайте самоподписанный сертификат для использования с вашим сервером. Выполните следующую команду в директории `ansiblebook/ch03/playbooks`, чтобы сгенерировать сертификат:

```bash
$ openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -subj /CN=localhost \
    -keyout files/nginx.key -out files/nginx.crt
```

Эта команда создаст файлы `nginx.key` и `nginx.crt`, которые будут использоваться для настройки Nginx с TLS.

### Задание 2: Работа с переменными

Создайте плейбук, который включает переменные для настройки путей и файлов сертификатов.

Пример:

```yaml
vars:
  tls_dir: /etc/nginx/ssl/
  key_file: nginx.key
  cert_file: nginx.crt
  conf_file: /etc/nginx/sites-available/default
  server_name: localhost
```

### Пример плейбука: webservers-tls.yml

```yaml
---
- name: Configure webserver with Nginx and TLS
  hosts: webservers
  become: true
  gather_facts: false
  vars:
    tls_dir: /etc/nginx/ssl/
    key_file: nginx.key
    cert_file: nginx.crt
    conf_file: /etc/nginx/sites-available/default
    server_name: localhost

  handlers:
    - name: Restart nginx
      service:
        name: nginx
        state: restarted

  tasks:
    - name: Ensure nginx is installed
      package:
        name: nginx
        update_cache: true
      notify: Restart nginx

    - name: Create directories for TLS certificates
      file:
        path: "{{ tls_dir }}"
        state: directory
        mode: '0750'
      notify: Restart nginx

    - name: Copy TLS files
      copy:
        src: "{{ item }}"
        dest: "{{ tls_dir }}"
        mode: '0600'
      loop:
        - "{{ key_file }}"
        - "{{ cert_file }}"
      notify: Restart nginx

    - name: Manage nginx config template
      template:
        src: nginx.conf.j2
        dest: "{{ conf_file }}"
        mode: '0644'
      notify: Restart nginx

    - name: Enable configuration
      file:
        src: /etc/nginx/sites-available/default
        dest: /etc/nginx/sites-enabled/default
        state: link

    - name: Install home page
      template:
        src: index.html.j2
        dest: /usr/share/nginx/html/index.html
        mode: '0644'

    - name: Restart nginx
      meta: flush_handlers

    - name: "Test it! https://localhost:8443/index.html"
      delegate_to: localhost
      become: false
      uri:
        url: 'https://localhost:8443/index.html'
        validate_certs: false
        return_content: true
      register: this
      failed_when: "'Running on ' not in this.content"
      tags:
        - test
```

### Шаблон конфигурации Nginx: nginx.conf.j2

Создайте файл шаблона в директории `templates/nginx.conf.j2`:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;
    listen 443 ssl;
    ssl_protocols TLSv1.2;
    ssl_prefer_server_ciphers on;
    root /usr/share/nginx/html;
    index index.html;
    server_tokens off;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    server_name {{ server_name }};
    ssl_certificate {{ tls_dir }}{{ cert_file }};
    ssl_certificate_key {{ tls_dir }}{{ key_file }};
    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Задание 3: Тестирование и проверка

Добавьте тест, который проверяет работу вашего сервера с помощью модуля `uri`. Вот пример теста:

```yaml
- name: "Test it! https://localhost:8443/index.html"
  uri:
    url: 'https://localhost:8443/index.html'
    validate_certs: false
    return_content: true
  register: result
  failed_when: "'Running on ' not in result.content"
```

### Вопросы для проверки:

1. **Что такое переменные в Ansible и как они помогают при написании сценариев?**
2. **Почему важно использовать кавычки при передаче переменных в аргументах?**
3. **Как работают обработчики в Ansible и как они связаны с уведомлениями?**
4. **Какие типичные ошибки могут возникать при работе с циклом `loop` в Ansible?**
5. **Как проверить, что самоподписанный сертификат был успешно установлен и сервер работает с использованием TLS?**

### Дополнительные задания:

1. **Настройка перенаправления с HTTP на HTTPS:**  
   Настройте Nginx так, чтобы он перенаправлял все HTTP-запросы на HTTPS. Это можно сделать с помощью отдельного сервера в шаблоне.

2. **Проверка срока действия сертификата:**  
   Настройте задачу, которая проверяет срок действия TLS-сертификата и уведомляет, если срок истекает через 30 дней.

3. **Автоматическое обновление сертификатов:**  
   Создайте задачу, которая автоматически генерирует новый самоподписанный сертификат, если текущий сертификат истекает.

4. **Логи и отладка:**  
   Используйте модуль `debug`, чтобы выводить важную информацию о ходе выполнения плейбука и переменных.

### Запуск сценария

Запустите ваш сценарий командой:

```bash
ansible-playbook webservers-tls.yml
```

Проверьте результат выполнения и убедитесь, что сервер доступен по адресу `https://localhost:8443`.

### Заключение

Эта лабораторная работа показала, как настроить веб-сервер Nginx с поддержкой TLS, а также научила вас работать с переменными, циклами и обработчиками в Ansible. Вы также освоили тестирование и проверку конфигураций с использованием модуля `uri`.
