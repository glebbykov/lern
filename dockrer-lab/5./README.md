
# Лабораторная работа №5: Управление секретами и настройками в Docker

## Цели работы
1. Ознакомиться с механизмами управления секретами в Docker.
2. Изучить использование конфигурационных файлов (configs) в Docker.
3. Освоить применение секретов и конфигураций в Docker Compose.
4. Понять назначение и области применения секретов и конфигураций.

---

## 1. Теоретическая часть
### Секреты в Docker
- **Что такое секреты?**
  - Секреты — это чувствительная информация (например, пароли, ключи), безопасно передаваемая в контейнеры.
- **Как создаются секреты?**
  - Используются команды `docker secret create` и `docker secret ls`.
- **Использование секретов:**
  - Секреты можно подключать только к контейнерам, запущенным в режиме Swarm.

### Конфигурации в Docker
- **Что такое конфигурации?**
  - Конфигурационные файлы, хранящие настройки приложения.
- **Создание конфигураций:**
  - Команды `docker config create` и `docker config ls`.
- **Использование конфигураций:**
  - Конфигурации подключаются к контейнерам, работающим в режиме Swarm.

### Работа с секретами и конфигурациями в Docker Compose
- Использование секции `secrets` и `configs` в `docker-compose.yml` для подключения секретов и конфигураций.

---

## 2. Практическая часть
### Работа с секретами
1. Перейдите в рабочую директорию:
    ```bash
    mkdir docker-secrets && cd docker-secrets
    ```
    
выполнить команду:
    ```
    docker swarm init
    ```
2. Создайте секрет с именем `my_secret`:
    ```bash
    echo "super_secret_password" | docker secret create my_secret -
    ```

3. Проверьте список секретов:
    ```bash
    docker secret ls
    ```

4. Создайте `docker-compose.yml` для использования секрета:
    ```yaml
    version: '3.8'
    services:
      app:
        image: nginx
        secrets:
          - my_secret
    secrets:
      my_secret:
        external: true
    ```

5. Запустите приложение и убедитесь, что секрет доступен в контейнере.

### Работа с конфигурациями
1. Создайте конфигурационный файл:
    ```bash
    echo "server { listen 80; }" > nginx.conf
    docker config create nginx_config nginx.conf
    ```

2. Проверьте список конфигураций:
    ```bash
    docker config ls
    ```

3. Обновите `docker-compose.yml`, чтобы использовать конфигурацию:
    ```yaml
    version: '3.8'
    services:
      app:
        image: nginx
        configs:
          - source: nginx_config
            target: /etc/nginx/nginx.conf
    configs:
      nginx_config:
        external: true
    ```

4. Запустите приложение и убедитесь, что конфигурация применилась.

---

## 3. Теоретические вопросы
1. Какие типы данных можно передавать в Docker секретах?
2. Почему секреты доступны только в режиме Swarm?
3. В чем отличие между секретами и конфигурациями?
4. Как проверить, что секреты или конфигурации применились к контейнеру?
5. Как удалить ненужные секреты и конфигурации?

---

## 4. Дополнительные задания
1. **Модификация секретов:**
   - Попробуйте заменить существующий секрет новым содержимым и проверьте его доступность в контейнере.

2. **Множественные конфигурации:**
   - Подключите два конфигурационных файла к одному контейнеру и настройте их применение.

3. **Защита секретов:**
   - Проверьте, что секреты недоступны за пределами контейнера (например, с хоста).

4. **Сравнение конфигураций:**
   - Создайте две версии конфигурации и протестируйте обновление конфигурации на работающем контейнере.

