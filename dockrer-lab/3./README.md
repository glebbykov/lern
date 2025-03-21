
# Лабораторная работа №3: Создание и управление собственными образами Docker

## Цели работы
1. Научиться создавать собственные образы с использованием Dockerfile.
2. Освоить добавление и удаление слоев в образах.
3. Изучить работу с тегами и управление версиями образов.
4. Познакомиться с оптимизацией Dockerfile.

---

## 1. Теоретическая часть
### Что такое Dockerfile?
- Файл инструкций для создания образа Docker.
- Основные инструкции:
  - `FROM`: базовый образ.
  - `RUN`: выполнение команд в контейнере.
  - `COPY` и `ADD`: копирование файлов в образ.
  - `CMD` и `ENTRYPOINT`: команды, выполняемые при запуске контейнера.
  - `WORKDIR`: установка рабочей директории.

### Управление образами
- Создание образа: `docker build`.
- Тегирование образов: `docker tag`.
- Загрузка образов в Docker Hub: `docker push`.

### Оптимизация Dockerfile
- Уменьшение количества слоев.
- Использование минимальных базовых образов (например, `alpine`).
- Кэширование слоев.

---

## 2. Практическая часть
### Создание собственного образа
1. Создайте директорию для работы:
    ```bash
    mkdir my-docker-image
    cd my-docker-image
    ```

2. Создайте Dockerfile с следующим содержимым:
    ```dockerfile
    FROM ubuntu:20.04
    RUN apt update && apt install -y curl
    COPY index.html /var/www/html/index.html
    CMD ["bash"]
    ```

3. Добавьте файл `index.html` с простым содержимым:
    ```html
    <html>
    <body>
        <h1>Hello, Docker!</h1>
    </body>
    </html>
    ```

4. Соберите образ:
    ```bash
    docker build -t my-ubuntu-image .
    ```

5. Запустите контейнер на основе созданного образа:
    ```bash
    docker run -it my-ubuntu-image
    ```

### Работа с тегами
1. Создайте тег для образа:
    ```bash
    docker tag my-ubuntu-image my-repo/my-ubuntu-image:v1
    ```

2. Загрузите образ в Docker Hub (если у вас есть учетная запись):
    ```bash
    docker login
    docker push my-repo/my-ubuntu-image:v1
    ```

### Оптимизация образа
1. Измените базовый образ на `alpine` в Dockerfile:
    ```dockerfile
    FROM alpine:3.18
    RUN apk add --no-cache curl
    COPY index.html /var/www/html/index.html
    CMD ["sh"]
    ```

2. Пересоберите образ и проверьте его размер:
    ```bash
    docker build -t my-alpine-image .
    docker images
    ```

---

## 3. Теоретические вопросы
1. Что такое слой в Docker образе?
2. Чем отличается инструкция `CMD` от `ENTRYPOINT`?
3. Как кэшируются слои при сборке образа?
4. Почему важно оптимизировать размер образов?
5. Какой флаг используется для задания имени образа при сборке?

---

## 4. Дополнительные задания
1. **Создание образа с приложением:**
   - Создайте Dockerfile для простого веб-сервера на базе `nginx` и добавьте в него кастомизированную страницу.

2. **Множественные инструкции RUN:**
   - Создайте два Dockerfile: один с несколькими инструкциями `RUN`, а другой с одной объединенной инструкцией. Сравните их размеры.

3. **Использование ENTRYPOINT:**
   - Напишите Dockerfile с использованием `ENTRYPOINT`, чтобы образ принимал аргументы при запуске.

4. **Удаление старых образов:**
   - Найдите и удалите ненужные образы на вашем хосте.

