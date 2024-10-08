
# Лабораторная работа: Создание пакетов Git на Linux

## Цель работы:
Научиться использовать команду `git bundle` для создания пакетов с изменениями в Git и передачи их без использования сети.

## Основные команды:
1. **git bundle create** — создание пакета с изменениями.
2. **git bundle verify** — проверка содержимого пакета.
3. **git bundle list-heads** — отображение веток, которые содержатся в пакете.
4. **git fetch** — извлечение изменений из пакета.

## Задание 1: Создание пакета с репозиторием
1. Инициализируйте новый Git-репозиторий и сделайте несколько коммитов:
    ```bash
    git init my_repo
    cd my_repo
    touch file1
    git add file1
    git commit -m "First commit"
    touch file2
    git add file2
    git commit -m "Second commit"
    ```

2. Создайте пакет для передачи репозитория:
    ```bash
    git bundle create repo.bundle HEAD master
    ```

## Задание 2: Клонирование из пакета
1. Передайте файл `repo.bundle` на другой компьютер или в другую директорию и клонируйте репозиторий:
    ```bash
    git clone repo.bundle cloned_repo
    cd cloned_repo
    ```

2. Проверьте, что коммиты были клонированы:
    ```bash
    git log
    ```

## Задание 3: Создание пакета с изменениями
1. Сделайте несколько новых коммитов в репозитории:
    ```bash
    touch file3
    git add file3
    git commit -m "Third commit"
    ```

2. Создайте пакет только с последними изменениями:
    ```bash
    git bundle create changes.bundle master ^origin/master
    ```

## Задание 4: Проверка и извлечение пакета
1. Проверьте пакет на другом компьютере или в другой директории:
    ```bash
    git bundle verify ../changes.bundle
    ```

2. Извлеките изменения из пакета:
    ```bash
    git fetch ../changes.bundle master:other-master
    ```

## Заключение
В ходе данной лабораторной работы вы научились создавать и использовать пакеты Git для передачи изменений без использования сети. Вы также узнали, как проверять содержимое пакетов и извлекать коммиты из них.
