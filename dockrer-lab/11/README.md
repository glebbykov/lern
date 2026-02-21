
# Лабораторная работа №11: Docker Trust, Hub и Registry

## Цели работы
1. Изучить принципы Docker Content Trust (DCT) для проверки подлинности образов.
2. Освоить работу с Docker Hub как публичным реестром образов.
3. Познакомиться с возможностями создания и управления приватными реестрами Docker.
4. Понять, как использовать подписи для образов и управлять доступом к ним.

---

## 1. Теоретическая часть
### Docker Content Trust (DCT)
- **Что такое Docker Content Trust?**
  - Механизм для подписания и проверки подлинности образов.
- **Ключевые концепции:**
  - Подпись образов с использованием TUF (The Update Framework).
  - Переменная окружения `DOCKER_CONTENT_TRUST=1` для включения проверки подписей.
- **Команды DCT:**
  - `docker trust sign` — подпись образа.
  - `docker trust inspect` — проверка информации о подписях.

### Docker Hub
- **Что такое Docker Hub?**
  - Публичный реестр образов Docker.
- **Возможности:**
  - Хранение публичных и приватных репозиториев.
  - Использование автоматической сборки образов.

### Docker Registry
- **Что такое Docker Registry?**
  - Приватный реестр для хранения образов.
- **Установка и использование:**
  - Запуск локального реестра с использованием образа `registry`.

---

## 2. Практическая часть
### Работа с Docker Content Trust
1. Включите Docker Content Trust:
    ```bash
    export DOCKER_CONTENT_TRUST=1
    ```

2. Подпишите образ:
    ```bash
    docker trust sign your-repo/your-image:latest
    ```

3. Проверьте информацию о подписях образа:
    ```bash
    docker trust inspect your-repo/your-image:latest
    ```

4. Попробуйте загрузить неподписанный образ и убедитесь, что это невозможно.

### Работа с Docker Hub
1. Загрузите образ в Docker Hub:
    ```bash
    docker tag your-image your-dockerhub-repo/your-image:latest
    docker push your-dockerhub-repo/your-image:latest
    ```

2. Проверьте наличие образа в вашем репозитории на Docker Hub.

3. Настройте автоматическую сборку образов с использованием GitHub или GitLab.

### Работа с Docker Registry
1. Запустите локальный Docker Registry:
    ```bash
    docker run -d -p 5000:5000 --name registry registry:2
    ```

2. Загрузите образ в локальный реестр:
    ```bash
    docker tag your-image localhost:5000/your-image:latest
    docker push localhost:5000/your-image:latest
    ```

3. Скачайте образ из реестра и запустите контейнер:
    ```bash
    docker pull localhost:5000/your-image:latest
    docker run -d localhost:5000/your-image:latest
    ```

---

## 3. Теоретические вопросы
1. Что такое Docker Content Trust и зачем он нужен?
2. Как включить проверку подписей для образов в Docker?
3. В чем разница между Docker Hub и Docker Registry?
4. Какие преимущества предоставляет использование приватного реестра?
5. Как проверить, что образ подписан с использованием DCT?

---

## 4. Дополнительные задания
1. **Подпись и загрузка образа в приватный реестр:**
   - Настройте DCT для локального Docker Registry и загрузите подписанный образ.

2. **Настройка аутентификации в локальном реестре:**
   - Настройте учетные записи для доступа к вашему локальному реестру.

3. **Интеграция с CI/CD:**
   - Настройте автоматическую подпись и загрузку образов в реестр при сборке в CI/CD.

4. **Репликация реестров:**
   - Настройте репликацию образов между локальным Docker Registry и Docker Hub.
   
