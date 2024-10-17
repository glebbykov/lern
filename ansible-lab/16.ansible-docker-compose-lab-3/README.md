
# Лабораторная работа №16
## Тема: Расширенные возможности Docker Compose

### Цель работы:
Изучить расширенные возможности Docker Compose, такие как настройка нескольких сетей, управление секретами, использование переменных окружения и обновление контейнеров без остановки приложения.

### Задачи:
1. Настроить несколько сетей для разделения доступа между сервисами.
2. Использовать переменные окружения для конфигурации сервисов.
3. Настроить работу с секретами в Docker Compose.
4. Реализовать обновление контейнера без остановки приложения (zero-downtime deployment).

### Оборудование и ПО:
- Установленный Docker и Docker Compose.
- Редактор текста для создания файлов `docker-compose.yml`.

### Теоретические вопросы:
1. Как можно разделить сервисы по сетям в Docker Compose и зачем это нужно?
2. Как использовать переменные окружения в Docker Compose?
3. Что такое секреты в Docker и как они используются?
4. Как Docker Compose позволяет обновлять контейнеры без остановки работы сервиса?
5. Какие преимущества даёт использование нескольких сетей в Docker Compose?

### Ход работы

#### 1. Настройка нескольких сетей
**Задание:**  
Создать файл `docker-compose.yml`, в котором будет два контейнера: один с NGINX и один с базой данных MySQL. Разделите их на две разные сети: публичную для доступа к NGINX и приватную для взаимодействия NGINX с MySQL.

**Решение:**  
```yaml
version: '3'
services:
  nginx:
    image: nginx
    ports:
      - "8080:80"
    networks:
      - public_net
      - private_net

  db:
    image: mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
    networks:
      - private_net

networks:
  public_net:
  private_net:
```

#### 2. Использование переменных окружения
**Задание:**  
Добавьте переменные окружения для настройки NGINX и MySQL, используя `.env` файл для хранения чувствительных данных.

**Решение:**  
Создайте файл `.env` со следующими переменными:
```bash
MYSQL_ROOT_PASSWORD=rootpassword
NGINX_PORT=8080
```

И обновите файл `docker-compose.yml`:
```yaml
version: '3'
services:
  nginx:
    image: nginx
    ports:
      - "${NGINX_PORT}:80"
    networks:
      - public_net
      - private_net

  db:
    image: mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    networks:
      - private_net
```

#### 3. Настройка секретов
**Задание:**  
Настройте секреты для передачи паролей базы данных MySQL в контейнер через Docker Compose.

**Решение:**  
Создайте файл секретов `secrets/mysql_password.txt` с содержимым:
```
supersecretpassword
```

И обновите `docker-compose.yml` для использования секретов:
```yaml
version: '3.7'
services:
  db:
    image: mysql
    environment:
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/mysql_password
    secrets:
      - mysql_password
    networks:
      - private_net

secrets:
  mysql_password:
    file: ./secrets/mysql_password.txt

networks:
  private_net:
```

#### 4. Обновление контейнеров без остановки
**Задание:**  
Реализуйте zero-downtime deployment для NGINX. Обновите контейнер с NGINX без остановки работы сервиса.

**Решение:**  
Используйте стратегию обновления с минимумом остановок сервиса. Пример `docker-compose.override.yml`:
```yaml
version: '3'
services:
  nginx:
    deploy:
      update_config:
        parallelism: 2
        delay: 10s
      restart_policy:
        condition: on-failure
```

Запустите команду для обновления контейнера:
```bash
docker-compose up -d --no-deps --build nginx
```

### Дополнительные задания:
1. **Реализуйте мониторинг контейнеров:**  
Настройте Prometheus и Grafana для мониторинга состояния контейнеров NGINX и MySQL.

2. **Масштабирование базы данных:**  
Добавьте репликацию между двумя контейнерами MySQL для увеличения отказоустойчивости.

3. **Балансировка нагрузки:**  
Настройте HAProxy или Traefik для распределения запросов между несколькими контейнерами NGINX.

4. **Управление логами:**  
Создайте отдельный сервис для сбора и управления логами контейнеров (например, используя ELK-стек).

### Вопросы для самопроверки:
1. Какую роль играют сети в Docker Compose?
2. Как работает директива `secrets` в Docker Compose и зачем она нужна?
3. Как можно передавать переменные окружения контейнерам в Docker Compose?
4. В чем преимущества использования zero-downtime deployment?
5. Как Docker Compose управляет обновлением контейнеров при использовании директивы `update_config`?

### Заключение:
В данной лабораторной работе были рассмотрены расширенные возможности Docker Compose, включая работу с несколькими сетями, секретами и переменными окружения. Также была изучена стратегия zero-downtime deployment для обновления контейнеров без остановки работы сервисов.
