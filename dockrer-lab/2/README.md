
# Лабораторная работа №2: Управление контейнерами и сетями в Docker

## Цели работы
1. Изучить управление контейнерами и их настройками.
2. Понять основы работы с сетями в Docker.
3. Освоить подключение контейнеров к пользовательским сетям.
4. Научиться использовать тома для хранения данных.

---

## 1. Теоретическая часть
### Управление контейнерами
- Повторное использование остановленных контейнеров: `docker start`, `docker restart`.
- Управление состоянием контейнеров: `docker pause`, `docker unpause`.
- Удаление контейнеров: `docker rm`.

### Сети в Docker
- Типы сетей:
  - **bridge** — стандартная сеть для изолированных контейнеров.
  - **host** — использование сети хоста.
  - **none** — контейнер без сети.
- Создание пользовательских сетей: `docker network create`.
- Подключение контейнера к сети: `docker network connect`.

### Тома в Docker
- Что такое тома и зачем они нужны.
- Создание томов: `docker volume create`.
- Подключение томов к контейнерам: флаг `-v` или `--mount`.

---

## 2. Практическая часть
### Управление состоянием контейнеров
1. Запустите контейнер `nginx` и приостановите его выполнение:
    ```bash
    docker run -d --name test-nginx nginx
    docker pause test-nginx
    docker unpause test-nginx
    ```

2. Перезапустите контейнер и проверьте его статус:
    ```bash
    docker restart test-nginx
    docker ps
    ```

3. Удалите контейнер:
    ```bash
    docker rm -f test-nginx
    ```

### Работа с сетями
1. Просмотрите список сетей:
    ```bash
    docker network ls
    ```

2. Создайте пользовательскую сеть и запустите контейнер, подключив его к этой сети:
    ```bash
    docker network create my-network
    docker run -d --name network-test --network my-network nginx
    ```

3. Подключите другой контейнер к той же сети и проверьте их взаимодействие:
    ```bash
    docker run -d --name network-test2 --network my-network alpine sh -c "while true; do sleep 3600; done"
    docker exec -it network-test2 ping -c 3 network-test
    ```

4. Удалите созданную сеть:
    ```bash
    docker network rm my-network
    ```

### Работа с томами
1. Создайте том и подключите его к контейнеру `nginx` для хранения данных:
    ```bash
    docker volume create nginx-data
    docker run -d --name nginx-volume -v nginx-data:/usr/share/nginx/html nginx
    ```

2. Запишите данные в том:
    ```bash
    docker exec -it nginx-volume bash -c "echo 'Hello, Docker' > /usr/share/nginx/html/index.html"
    ```

3. Удалите контейнер и убедитесь, что данные остались в томе:
    ```bash
    docker rm -f nginx-volume
    docker run -it --rm -v nginx-data:/data alpine cat /data/index.html
    ```

---

## 3. Теоретические вопросы
1. Какие типы сетей поддерживает Docker?
2. Как использовать пользовательские сети для взаимодействия контейнеров?
3. Чем отличается использование флага `-v` от `--mount` для подключения томов?
4. Что происходит с томами при удалении контейнера?
5. Для чего используется команда `docker network connect`?

---

## 4. Дополнительные задания
1. **Множественные сети:**
   - Создайте два контейнера в разных сетях и подключите их ко второй сети для взаимодействия.
     ```bash
     docker network create net1
     docker network create net2
     docker run -d --name container1 --network net1 alpine sh -c "while true; do sleep 3600; done"
     docker run -d --name container2 --network net2 alpine sh -c "while true; do sleep 3600; done"
     docker network connect net1 container2
     docker exec -it container2 ping -c 3 container1
     ```

2. **Тома и несколько контейнеров:**
   - Создайте том и используйте его одновременно в двух контейнерах. Проверьте синхронизацию данных.

3. **Сохранение данных:**
   - Создайте том для базы данных (например, `mysql`) и убедитесь, что данные сохраняются между перезапусками контейнера.
