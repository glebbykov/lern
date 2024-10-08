# Лабораторная работа 2: Основы ветвления и слияния в Git

## Цель:
Научиться создавать ветки, работать с параллельными ветками, исправлять ошибки, сливать ветки и разрешать конфликты при слиянии.

## Теоретическая часть:
В данной работе мы рассмотрим процесс создания веток, их слияния, а также решение конфликтов, возникающих при слиянии. Используя ветвление в Git, можно эффективно управлять разработкой, изолируя изменения, исправляя ошибки и сливая ветки по мере необходимости.

## Шаги для выполнения:

### Шаг 1: Инициализация репозитория
1. Инициализируйте новый репозиторий:
   ```bash
   git init
   ```

2. Добавьте несколько файлов и сделайте первый коммит:
   ```bash
   touch index.html
   git add index.html
   git commit -m "Initial commit"
   ```

### Шаг 2: Создание ветки для задачи
1. Создайте ветку для задачи #53 и переключитесь на неё:
   ```bash
   git checkout -b iss53
   ```

2. Сделайте изменения в файле и зафиксируйте их:
   ```bash
   echo "New footer content" >> index.html
   git commit -a -m "Create new footer [issue 53]"
   ```

### Шаг 3: Создание ветки для исправления ошибки
1. Переключитесь обратно на ветку `master`:
   ```bash
   git checkout master
   ```

2. Создайте ветку для исправления ошибки и переключитесь на неё:
   ```bash
   git checkout -b hotfix
   ```

3. Исправьте ошибку в файле и создайте коммит:
   ```bash
   echo "Fix email address" >> index.html
   git commit -a -m "Fix broken email address"
   ```

4. Выполните слияние ветки `hotfix` в `master`:
   ```bash
   git checkout master
   git merge hotfix
   ```

5. Удалите ветку `hotfix`:
   ```bash
   git branch -d hotfix
   ```

### Шаг 4: Продолжение работы над задачей
1. Переключитесь обратно на ветку `iss53` и продолжите работу:
   ```bash
   git checkout iss53
   echo "Final footer content" >> index.html
   git commit -a -m "Finish the new footer [issue 53]"
   ```

### Шаг 5: Слияние ветки задачи в основную ветку
1. Переключитесь на ветку `master` и выполните слияние ветки `iss53`:
   ```bash
   git checkout master
   git merge iss53
   ```

2. Удалите ветку `iss53`, так как она больше не нужна:
   ```bash
   git branch -d iss53
   ```

### Шаг 6: Разрешение конфликтов
1. В случае возникновения конфликтов при слиянии используйте команду `git status`, чтобы увидеть файлы с конфликтами:
   ```bash
   git status
   ```

2. Откройте файлы с конфликтами, исправьте их вручную и добавьте изменения в индекс:
   ```bash
   git add index.html
   ```

3. Завершите процесс слияния:
   ```bash
   git commit
   ```

## Дополнительные задания:
1. Выполните слияние веток с использованием опции `--no-ff` для создания отдельного коммита слияния:
   ```bash
   git merge --no-ff iss53
   ```

2. Разрешите конфликты с помощью инструмента слияния:
   ```bash
   git mergetool
   ```

## Вопросы для самопроверки:
1. Что такое fast-forward слияние?
2. Чем отличается fast-forward слияние от трёхстороннего слияния?
3. Какие команды используются для разрешения конфликтов в Git?

## Ожидаемый результат:
- Вы должны научиться эффективно работать с ветками, исправлять ошибки, выполнять слияния, а также разрешать конфликты в процессе слияния веток.
