
# Лабораторная работа №14
## Тема: Управление несколькими контейнерами на локальной машине

### Цель работы:
Изучить процесс управления несколькими контейнерами на локальной машине с помощью Docker Compose и Ansible.

### Задачи:
1. Создать и запустить несколько контейнеров с использованием Docker Compose.
2. Автоматизировать управление контейнерами с помощью Ansible.
3. Изучить процесс развертывания контейнеров на нескольких машинах.
4. Изучить работу с сетями Docker для связи контейнеров.

### Оборудование и ПО:
- Установленный Docker и Docker Compose.
- Установленный Ansible.

### Теоретические вопросы:
1. Что такое Docker Compose и зачем он нужен?
2. Какие директивы поддерживаются в файле docker-compose.yml?
3. Как работает модуль `docker_compose` в Ansible?
4. Как использовать сети Docker для связи между контейнерами?
5. Как можно безопасно передавать данные между контейнерами?

### Ход работы

#### 1. Создание docker-compose.yml для NGINX и Ghost
**Задание:**  
Создать файл `docker-compose.yml` для запуска двух контейнеров: NGINX и Ghost.

**Решение:**  
```yaml
version: '2'
services:
  nginx:
    image: ansiblebook/nginx-ghost
    ports:
      - "8000:80"
      - "8443:443"
    volumes:
      - ${PWD}/certs:/certs
    links:
      - ghost
  ghost:
    image: ghost
```

#### 2. Создание Ansible-сценария для работы с Docker Compose
**Задание:**  
Создать Ansible-сценарий для автоматического создания образов и запуска контейнеров с помощью Docker Compose.

**Решение:**  
```yaml
- name: Run Ghost locally
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Create Nginx image
      docker_image:
        build:
          path: ./nginx
        source: build
        name: bbaassssiiee/nginx-ghost
        state: present
        force_source: "{{ force_source | default(false) }}"
        tag: "{{ tag | default('v1') }}"
    - name: Create certs
      command: >
        openssl req -new -x509 -nodes
        -out certs/nginx.crt -keyout certs/nginx.key
        -subj '/CN=localhost' -days 365
      args:
        creates: certs/nginx.crt
    - name: Bring up services
      docker_compose:
        project_src: .
        state: present
```

#### 3. Использование сетей Docker для связи контейнеров
**Задание:**  
Создать сеть Docker и связать контейнеры NGINX и Ghost для взаимодействия через нее.

**Решение:**  
```yaml
- name: Create network
  docker_network:
    name: ghostnet
```

#### 4. Запрос информации о локальных образах
**Задание:**  
С помощью модуля `docker_image_info` получить информацию о локальных Docker-образах, включая порты и тома.

**Решение:**  
```yaml
- name: Get exposed ports and volumes
  hosts: localhost
  gather_facts: false
  vars:
    image: ghost
  tasks:
    - name: Get image info
      docker_image_info:
        name: ghost
      register: ghost
    - name: Extract ports
      set_fact:
        ports: "{{ ghost.images[0].Config.ExposedPorts.keys() }}"
    - name: Output exposed port
      debug:
        msg: "Exposed port: {{ ports[0] }}"
    - name: Extract volumes
      set_fact:
        volumes: "{{ ghost.images[0].Config.Volumes.keys() }}"
    - name: Output volumes
      debug:
        msg: "Volume: {{ item }}"
      with_items: "{{ volumes }}"
```

### Дополнительные задания:
1. **Настройка сети и нескольких контейнеров:**  
Используйте Docker Compose для настройки сети и запуска контейнеров Ghost и NGINX, чтобы они взаимодействовали через созданную сеть.
2. **Развертывание на нескольких машинах:**  
Создайте Ansible-сценарий для развертывания контейнеров Ghost и MySQL на разных машинах.
3. **Управление базой данных MySQL:**  
Создайте контейнер с MySQL для использования в связке с Ghost, настройте автоматическое создание базы данных и пользователя для Ghost.
4. **Мониторинг состояния контейнеров:**  
Добавьте задачи для мониторинга состояния контейнеров NGINX и Ghost с использованием Ansible.

### Вопросы для самопроверки:
1. Какие основные директивы используются в файле docker-compose.yml?
2. Как работает модуль `docker_compose` в Ansible?
3. Какие сети поддерживает Docker и как они используются для связи контейнеров?
4. Как получить информацию о портах и томах Docker-образа?
5. Как обеспечить безопасность передачи данных между контейнерами в сети Docker?

### Заключение:
В ходе лабораторной работы было изучено управление несколькими контейнерами на локальной машине с использованием Docker Compose и Ansible. Рассмотрены вопросы настройки сетей Docker, мониторинга контейнеров и развертывания баз данных.
