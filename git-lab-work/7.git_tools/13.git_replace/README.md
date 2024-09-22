
# Лабораторная работа: Замена объектов в Git на Linux

## Цель работы:
Научиться использовать команду `git replace` для замены одного объекта в истории Git другим без изменения значений SHA-1.

## Основные команды:
1. **git replace** — замена одного объекта в истории Git другим.
2. **git commit-tree** — создание коммита на основе дерева без указания родителей.
3. **git rebase --onto** — перебазирование истории на другой коммит.

## Задание 1: Подготовка репозитория
1. Инициализируйте новый репозиторий и создайте несколько коммитов:
    ```bash
    git init my_repo
    cd my_repo
    echo "First commit" > file1
    git add file1
    git commit -m "First commit"
    echo "Second commit" > file2
    git add file2
    git commit -m "Second commit"
    echo "Third commit" > file3
    git add file3
    git commit -m "Third commit"
    echo "Fourth commit" > file4
    git add file4
    git commit -m "Fourth commit"
    echo "Fifth commit" > file5
    git add file5
    git commit -m "Fifth commit"
    ```

## Задание 2: Создание исторической ветки
1. Создайте ветку `history` на основе четвертого коммита:
    ```bash
    git branch history HEAD~1
    ```

2. Отправьте ветку `history` в удаленный репозиторий:
    ```bash
    git remote add project-history <URL_исторического_репозитория>
    git push project-history history:master
    ```

## Задание 3: Создание базового коммита
1. Создайте новый коммит с инструкциями для получения полной истории:
    ```bash
    echo 'Get history from the historical repository' | git commit-tree HEAD~2^{tree}
    ```

2. Используйте SHA-1 хеш нового коммита для перебазирования оставшихся коммитов:
    ```bash
    git rebase --onto <SHA_нового_коммита> <SHA_третьего_коммита>
    ```

## Задание 4: Замена коммита
1. Замените четвертый коммит в текущей ветке на коммит из ветки `history`:
    ```bash
    git replace <SHA_четвертого_коммита> <SHA_четвертого_коммита_из_history>
    ```

2. Проверьте изменения в истории:
    ```bash
    git log --oneline
    ```

## Заключение
В данной лабораторной работе вы научились использовать команду `git replace` для замены объектов в истории Git, а также узнали, как сохранять неизменными SHA-1 хеши коммитов при манипуляциях с историей.
