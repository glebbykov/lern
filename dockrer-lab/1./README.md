
# Лабораторная работа №1: Введение в Docker

## Цели работы
1. Изучить основные концепции и термины Docker.
2. Установить Docker на локальную машину.
3. Научиться запускать контейнеры, управлять ими и взаимодействовать с Docker CLI.
4. Ознакомиться с базовыми командами для работы с образами и контейнерами.

---

## 1. Теоретическая часть
### Что такое Docker?
- Основные понятия: контейнер, образ, Docker Engine.
- Различия между виртуальными машинами и контейнерами.

### Архитектура Docker:
- Docker Daemon.
- Docker CLI.
- Docker Registry (Docker Hub).

### Основные команды Docker:
- `docker pull`, `docker run`, `docker ps`, `docker stop`, `docker rm`, `docker rmi`.

### Сценарии использования Docker:
- Разработка приложений.
- CI/CD.
- Изоляция окружений.

---

## 2. Практическая часть
### Установка Docker:
- Установите Docker на своей системе согласно официальной документации. Убедитесь, что служба Docker запущена.

### Работа с контейнерами:
1. Запустите контейнер с образом `hello-world`:
    ```bash
    docker run hello-world
    ```
2. Запустите контейнер на основе образа `nginx`, убедитесь, что сервер доступен на `localhost:80`:
    ```bash
    docker run -d -p 80:80 nginx
    ```
3. Остановите и удалите контейнер:
    ```bash
    docker stop <container_id>
    docker rm <container_id>
    ```

### Работа с образами:
1. Загрузите образ `alpine` и запустите контейнер с этим образом в интерактивном режиме:
    ```bash
    docker pull alpine
    docker run -it alpine sh
    ```
2. Удалите образ `alpine`:
    ```bash
    docker rmi alpine
    ```

### Просмотр информации о Docker:
1. Просмотрите запущенные контейнеры:
    ```bash
    docker ps
    ```
2. Просмотрите все контейнеры:
    ```bash
    docker ps -a
    ```
3. Получите список загруженных образов:
    ```bash
    docker images
    ```

---

## 3. Теоретические вопросы
1. Что такое контейнер, и чем он отличается от виртуальной машины?
2. Что происходит при выполнении команды `docker run`?
3. Какие команды Docker позволяют управлять контейнерами?
4. Как работает изоляция процессов и ресурсов в Docker?
5. Для чего используется Docker Hub?

---

## 4. Дополнительные задания
1. **Изучение логов контейнера:**
   - Запустите контейнер на основе образа `nginx` и посмотрите его логи.
     ```bash
     docker logs <container_id>
     ```

2. **Модификация контейнера:**
   - Запустите контейнер `ubuntu`, установите в нем пакет `curl` и выполните HTTP-запрос к `example.com`.
     ```bash
     docker run -it ubuntu
     apt update && apt install curl -y
     curl http://example.com
     ```

3. **Создание собственного образа:**
   - Используйте Dockerfile для создания простого образа с веб-сервером (например, `nginx` с HTML-файлом).