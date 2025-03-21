
# Лабораторная работа №10: Альтернативные инструменты для работы с Docker

## Цели работы
1. Изучить альтернативные инструменты для управления контейнерами.
2. Ознакомиться с возможностями Podman, Buildah и Skopeo.
3. Освоить базовые команды для работы с альтернативными инструментами.
4. Понять различия между Docker и его альтернативами.

---

## 1. Теоретическая часть
### Podman
- **Что такое Podman?**
  - Инструмент для управления контейнерами без необходимости запуска демона Docker.
- **Основные отличия от Docker:**
  - Бездемонная архитектура.
  - Поддержка rootless контейнеров.
- **Команды Podman:**
  - `podman run` — запуск контейнера.
  - `podman ps` — список запущенных контейнеров.
  - `podman build` — создание образов.

### Buildah
- **Что такое Buildah?**
  - Инструмент для создания и управления образами контейнеров.
- **Возможности:**
  - Создание образов без необходимости использования Dockerfile.
  - Интеграция с Podman.

### Skopeo
- **Что такое Skopeo?**
  - Утилита для работы с образами контейнеров в различных хранилищах.
- **Возможности:**
  - Копирование образов между реестрами.
  - Просмотр и подпись образов.

---

## 2. Практическая часть
### Установка инструментов
1. Установите Podman, Buildah и Skopeo на вашей системе (следуйте официальной документации).

### Работа с Podman
1. Запустите контейнер на основе образа `nginx`:
    ```bash
    podman run -d --name podman-nginx -p 8080:80 nginx
    ```

2. Проверьте список запущенных контейнеров:
    ```bash
    podman ps
    ```

3. Остановите контейнер и удалите его:
    ```bash
    podman stop podman-nginx
    podman rm podman-nginx
    ```

### Работа с Buildah
1. Создайте новый образ на основе `alpine` и установите в нем пакет `curl`:
    ```bash
    buildah from alpine:latest
    buildah run alpine-working-container -- apk add curl
    buildah commit alpine-working-container custom-alpine
    ```

2. Проверьте созданный образ:
    ```bash
    podman images
    ```

### Работа с Skopeo
1. Скопируйте образ из Docker Hub в локальное хранилище:
    ```bash
    skopeo copy docker://alpine:latest dir:/tmp/alpine-image
    ```

2. Проверьте содержимое локального хранилища:
    ```bash
    ls /tmp/alpine-image
    ```

---

## 3. Теоретические вопросы
1. Чем Podman отличается от Docker?
2. Какие преимущества использования Buildah при создании образов?
3. Для чего используется Skopeo?
4. Как работает rootless режим в Podman?
5. Можно ли использовать Podman для управления многоконтейнерными приложениями?

---

## 4. Дополнительные задания
1. **Использование Podman Compose:**
   - Установите `podman-compose` и разверните многоконтейнерное приложение.

2. **Сравнение Podman и Docker:**
   - Настройте два одинаковых приложения с использованием Podman и Docker, сравните их производительность.

3. **Подпись образов:**
   - Используйте Skopeo для подписания образа и проверки подписи.

4. **Интеграция Buildah и Podman:**
   - Создайте образ с помощью Buildah и запустите контейнер на его основе с помощью Podman.
