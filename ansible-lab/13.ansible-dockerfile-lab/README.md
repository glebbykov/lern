
# Лабораторная работа №13
## Тема: Создание образа из Dockerfile

### Цель работы:
Изучить процесс создания Docker-образов на основе Dockerfile, а также управление ими с помощью Ansible.

### Задачи:
1. Создать Dockerfile для NGINX с поддержкой TLS и проксированием запросов на Ghost.
2. Собрать Docker-образ и отправить его в Docker Hub.
3. Автоматизировать процесс с помощью Ansible.
4. Изучить процесс передачи образов в нестандартный Docker-реестр.

### Оборудование и ПО:
- Установленный Docker.
- Установленный Ansible.
- Учётная запись в Docker Hub или альтернативном реестре.

### Теоретические вопросы:
1. Что такое Dockerfile и какие основные директивы он поддерживает?
2. Как работают многослойные образы в Docker и как это влияет на их создание?
3. В чем преимущества использования Ansible для управления контейнерами?
4. Какие способы обеспечения безопасности можно использовать при работе с Docker и Ansible?
5. Что такое TLS и зачем он нужен при настройке NGINX в контейнере?

### Ход работы

#### 1. Создание Dockerfile
**Задание:**  
Создать Dockerfile для настройки NGINX с поддержкой TLS и проксированием на Ghost через TCP-сокет.

**Решение:**

```Dockerfile
# Пример Dockerfile
FROM nginx
RUN rm /etc/nginx/conf.d/default.conf
COPY ghost.conf /etc/nginx/conf.d/ghost.conf
```

#### 2. Настройка конфигурации NGINX для работы с Ghost
**Задание:**  
Создать конфигурационный файл ghost.conf для NGINX, который будет обрабатывать запросы на сервер Ghost через TLS.

**Решение:**

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    client_max_body_size 10M;
    keepalive_timeout    15;
    ssl_certificate      /certs/nginx.crt;
    ssl_certificate_key  /certs/nginx.key;
    ssl_session_cache    shared:SSL:10m;
    ssl_session_timeout  10m;
    ssl_protocols TLSv1.3;
    ssl_ciphers EECDH+AESGCM:EDH+AESGCM;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass          http://ghost:2368;
        proxy_set_header    X-Real-IP $remote_addr;
        proxy_set_header    Host      $http_host;
        proxy_set_header    X-Forwarded-Proto https;
        proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

#### 3. Сборка Docker-образа с использованием Ansible
**Задание:**  
Создать Ansible-сценарий для сборки Docker-образа на основе Dockerfile.

**Решение:**

```yaml
- name: Create Nginx image
  docker_image:
    build:
      path: ./nginx
    source: build
    name: ansiblebook/nginx-ghost
    state: present
    force_source: "{{ force_source | default(false) }}"
    tag:  "{{ tag | default('latest') }}"
```

#### 4. Отправка образа в Docker Hub
**Задание:**  
Отправить собранный образ в Docker Hub.

**Решение:**

```yaml
- name: Publish image to docker hub
  hosts: localhost
  gather_facts: false
  vars_prompt:
    - name: username
      prompt: Enter Docker Registry username
    - name: password
      prompt: Enter Docker Registry password
      private: true
  tasks:
    - name: Authenticate with repository
      docker_login:
        username: "{{ username }}"
        password: "{{ password }}"
      tags:
        - login

    - name: Push image up
      docker_image:
        name: "ansiblebook/nginx-ghost"
        push: true
        source: local
        state: present
      tags:
        - push
```

#### 5. Настройка для нестандартного реестра
**Задание:**  
Изменить сценарий отправки Docker-образа в нестандартный реестр.

**Решение:**

```yaml
- name: Authenticate with repository
  docker_login:
    registry_url: https://reg.example.com
    username: "{{ username }}"
    password: "{{ password }}"
  tags:
    - login

- name: Push image up
  docker_image:
    name: reg.example.com/ansiblebook/nginx-ghost
    push: true
    source: local
    state: present
  tags:
    - push
```

### Дополнительные задания:
1. **Добавление номера версии образа:**  
Внесите изменения в docker_image так, чтобы каждый раз при сборке автоматически увеличивался номер версии.

2. **Шифрование данных:**  
Используйте Ansible Vault для шифрования учетных данных Docker-реестра.

3. **Развертывание нескольких контейнеров:**  
Создайте сценарий для автоматического развертывания нескольких контейнеров (NGINX и Ghost) в одном сценарии.

### Вопросы для самопроверки:
1. Какие ключевые инструкции используются в Dockerfile для копирования файлов и выполнения команд?
2. Как работает proxy_pass в NGINX и зачем он нужен в связке с Ghost?
3. Как можно управлять версиями Docker-образов с помощью Ansible?
4. Какие преимущества дает использование Ansible для работы с Docker-контейнерами по сравнению с использованием CLI Docker?
5. Какие методы шифрования используются при передаче данных между контейнерами и внешними пользователями через TLS?

### Заключение:
В ходе лабораторной работы были изучены ключевые этапы создания Docker-образов, их сборка и отправка в реестр с помощью Ansible. Было рассмотрено использование TLS для обеспечения безопасности и развертывание прокси-сервера NGINX перед приложением Ghost.
