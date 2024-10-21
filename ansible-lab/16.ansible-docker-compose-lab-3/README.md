
# Лабораторная работа №16
## Тема: Расширенные возможности Docker Compose с использованием Ansible

### Цель работы:
Изучить использование Ansible для автоматизации задач, аналогичных Docker Compose, включая настройку сетей, управление секретами, использование переменных окружения и обновление контейнеров без остановки приложения.

### Задачи:
1. Настроить несколько сетей для разделения доступа между сервисами с помощью Ansible.
2. Использовать переменные окружения для конфигурации сервисов в Ansible.
3. Настроить работу с секретами с помощью Ansible.
4. Реализовать обновление контейнера без остановки приложения (zero-downtime deployment) с помощью Ansible.

### Оборудование и ПО:
- Установленный Docker, Docker Compose и Ansible.
- Редактор текста для создания playbooks Ansible и файлов конфигурации.

### Теоретические вопросы:
1. Как можно разделить сервисы по сетям в Docker с помощью Ansible и зачем это нужно?
2. Как использовать переменные окружения в Ansible для конфигурации контейнеров Docker?
3. Что такое секреты в Docker и как их можно передать через Ansible?
4. Как Ansible позволяет обновлять контейнеры без остановки работы сервиса?
5. Какие преимущества даёт использование нескольких сетей при управлении контейнерами через Ansible?

### Ход работы

#### 1. Настройка нескольких сетей
**Задание:**  
Создать playbook Ansible, который создаст два контейнера: один с NGINX и один с базой данных MySQL, разделив их на две разные сети.

**Решение:**  
```yaml
---
- hosts: localhost
  tasks:
    - name: Create public network
      community.docker.docker_network:
        name: public_net
        state: present

    - name: Create private network
      community.docker.docker_network:
        name: private_net
        state: present

    - name: Start NGINX container
      community.docker.docker_container:
        name: nginx
        image: nginx
        state: started
        networks:
          - name: public_net
          - name: private_net
        ports:
          - "8080:80"

    - name: Start MySQL container
      community.docker.docker_container:
        name: db
        image: mysql
        state: started
        networks:
          - name: private_net
        env:
          MYSQL_ROOT_PASSWORD: rootpassword
```

#### 2. Использование переменных окружения
**Задание:**  
Добавить использование переменных окружения для настройки NGINX и MySQL через Ansible.

**Решение:**  
```yaml
---
- hosts: localhost
  vars:
    nginx_port: 8080
    mysql_root_password: rootpassword
  tasks:
    - name: Create public network
      community.docker.docker_network:
        name: public_net
        state: present

    - name: Create private network
      community.docker.docker_network:
        name: private_net
        state: present

    - name: Start NGINX container
      community.docker.docker_container:
        name: nginx
        image: nginx
        state: started
        networks:
          - name: public_net
          - name: private_net
        ports:
          - "{{ nginx_port }}:80"

    - name: Start MySQL container
      community.docker.docker_container:
        name: db
        image: mysql
        state: started
        networks:
          - name: private_net
        env:
          MYSQL_ROOT_PASSWORD: "{{ mysql_root_password }}"
```

#### 3. Настройка секретов
**Задание:**  
Настроить секреты для передачи паролей базы данных MySQL через Ansible.

**Решение:**  
```yaml
---
- hosts: localhost
  vars_files:
    - secrets.yml
  tasks:
    - name: Create private network
      community.docker.docker_network:
        name: private_net
        state: present

    - name: Start MySQL container with secret
      community.docker.docker_container:
        name: db
        image: mysql
        state: started
        networks:
          - name: private_net
        env:
          MYSQL_ROOT_PASSWORD: "{{ mysql_password }}"
```

##### В файле secrets.yml:
```yaml
mysql_password: "supersecretpassword"
```

#### 4. Обновление контейнеров без остановки
**Задание:**  
Реализовать обновление NGINX контейнера без остановки работы сервиса с помощью Ansible.
Простое решение с простоем:

**Решение:**  
```yaml
---
- hosts: localhost
  tasks:
    - name: Update NGINX container without downtime
      community.docker.docker_container:
        name: nginx
        image: nginx:latest
        state: started
        restart: yes
        recreate: true
        networks:
          - name: public_net
          - name: private_net
        ports:
          - "8080:80"
```
Сложное с поднятием дублирующего контейнера, но без простоя

```yaml
---
- hosts: localhost
  tasks:
    - name: Start new NGINX container
      community.docker.docker_container:
        name: nginx_new
        image: nginx:latest
        state: started
        recreate: true
        restart: yes
        networks:
          - name: public_net
          - name: private_net
        ports:
          - "8081:80"  # Временно запустить новый контейнер на другом порту
        healthcheck:   # Проверка здоровья контейнера
          test: ["CMD", "curl", "-f", "http://localhost:8081"]
          interval: 30s
          retries: 3
          timeout: 10s

    - name: Stop old NGINX container after new is healthy
      community.docker.docker_container:
        name: nginx_old
        state: stopped
        when: "'healthy' in docker_container_facts(name='nginx_new').json['State']['Health']['Status']"

    - name: Remove old NGINX container
      community.docker.docker_container:
        name: nginx_old
        state: absent

    - name: Rename new NGINX container to replace the old one
      community.docker.docker_container:
        name: nginx
        image: nginx:latest
        state: started
        recreate: true
        restart: yes
        networks:
          - name: public_net
          - name: private_net
        ports:
          - "8080:80"
```


### Дополнительные задания:
1. **Реализуйте мониторинг контейнеров:**  
Настройте Prometheus и Grafana с помощью Ansible для мониторинга состояния контейнеров NGINX и MySQL.

2. **Масштабирование базы данных:**  
Добавьте репликацию между двумя контейнерами MySQL для увеличения отказоустойчивости через Ansible.

3. **Балансировка нагрузки:**  
Настройте HAProxy или Traefik для распределения запросов между несколькими контейнерами NGINX с помощью Ansible.

4. **Управление логами:**  
Создайте отдельный сервис для сбора и управления логами контейнеров (например, используя ELK-стек) через Ansible.

### Вопросы для самопроверки:
1. Какую роль играют сети при управлении контейнерами через Ansible?
2. Как работает директива `env` в Ansible для Docker и зачем она нужна?
3. Как можно передавать переменные окружения контейнерам с помощью Ansible?
4. В чем преимущества использования zero-downtime deployment при управлении контейнерами через Ansible?
5. Как Ansible управляет обновлением контейнеров и поддерживает ли он аналогичные возможности Docker Compose?

### Заключение:
В данной лабораторной работе были рассмотрены расширенные возможности Ansible для работы с Docker, включая работу с несколькими сетями, секретами, переменными окружения и стратегией zero-downtime deployment.
