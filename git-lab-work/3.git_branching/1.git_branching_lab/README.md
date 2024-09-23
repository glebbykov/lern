# Лабораторная работа 1: Ветвление в Git

## Цель:
Научиться создавать ветки, переключаться между ними и управлять ветвлением в системе контроля версий Git.

## Теоретическая часть:
Ветвление в Git — это один из ключевых механизмов, позволяющий разработчикам параллельно работать над различными частями проекта, не мешая основной линии разработки. Ветки в Git являются легковесными и мгновенно создаются, что делает процесс ветвления удобным и эффективным.

## Шаги для выполнения:

### Шаг 1: Инициализация репозитория
1. Создайте новый репозиторий Git в локальной директории:
   ```bash
   git init
   ```

2. Добавьте несколько файлов в проект и выполните первый коммит:
   ```bash
   touch README.md file1.txt file2.txt
   git add .
   git commit -m "Initial commit"
   ```

### Шаг 2: Создание и работа с ветками
1. Создайте новую ветку `feature`:
   ```bash
   git branch feature
   ```

2. Переключитесь на ветку `feature`:
   ```bash
   git checkout feature
   ```

3. Внесите изменения в один из файлов:
   ```bash
   echo "New feature" >> file1.txt
   ```

4. Добавьте изменения и создайте новый коммит:
   ```bash
   git add file1.txt
   git commit -m "Added new feature in file1"
   ```

### Шаг 3: Возвращение в основную ветку
1. Переключитесь обратно на ветку `master`:
   ```bash
   git checkout master
   ```

2. Убедитесь, что изменения, внесенные в ветке `feature`, не отображаются в ветке `master`.

### Шаг 4: Слияние веток
1. Выполните слияние ветки `feature` в основную ветку:
   ```bash
   git merge feature
   ```

2. Убедитесь, что изменения из ветки `feature` появились в ветке `master`.

### Шаг 5: Визуализация истории коммитов
1. Визуализируйте историю коммитов и ветвления с помощью команды:
   ```bash
   git log --oneline --decorate --graph --all
   ```

### Шаг 6: Удаление ветки
1. После слияния вы можете удалить ветку `feature`, если она больше не нужна:
   ```bash
   git branch -d feature
   ```

## Дополнительные задания:
1. Одновременное создание и переключение на новую ветку:
   ```bash
   git checkout -b new-feature
   ```

2. Использование команды `git switch` для работы с ветками (начиная с версии Git 2.23):
   - Переключение на ветку:
     ```bash
     git switch feature
     ```
   - Создание и переключение на новую ветку:
     ```bash
     git switch -c new-branch
     ```

## Вопросы для самопроверки:
1. Как Git сохраняет состояние файлов при коммите?
2. Что представляет собой ветка в Git?
3. Как Git определяет, на какой ветке вы находитесь?
4. Какие команды используются для создания, переключения и удаления веток?

## Ожидаемый результат:
- В процессе выполнения лабораторной работы вы должны научиться работать с ветками в Git, понимать принцип работы ветвления, уметь сливать ветки и визуализировать историю коммитов.