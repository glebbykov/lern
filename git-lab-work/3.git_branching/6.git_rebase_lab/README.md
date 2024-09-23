# Лабораторная работа: Перебазирование в Git

## Цель:
Научиться использовать перебазирование для организации истории коммитов и переноса изменений из одной ветки в другую, а также узнать, в каких случаях перебазирование лучше не использовать.

## Теоретическая часть:
Перебазирование (rebase) — это способ переноса изменений из одной ветки поверх другой. Оно помогает упрощать историю коммитов, делая её линейной. В отличие от слияния (merge), которое создаёт новый коммит для объединения веток, перебазирование применяет изменения из одной ветки последовательно поверх другой.

## Шаги для выполнения:

### Шаг 1: Подготовка репозитория
1. Инициализируйте новый репозиторий и сделайте несколько коммитов в основной ветке:
   ```bash
   git init
   echo "Initial content" > file.txt
   git add file.txt
   git commit -m "Initial commit"
   ```

2. Создайте новую ветку `feature` и сделайте в ней несколько коммитов:
   ```bash
   git checkout -b feature
   echo "Feature work 1" >> file.txt
   git commit -a -m "Feature commit 1"
   echo "Feature work 2" >> file.txt
   git commit -a -m "Feature commit 2"
   ```

### Шаг 2: Выполнение перебазирования
1. Переключитесь обратно на основную ветку `master` и сделайте ещё один коммит:
   ```bash
   git checkout master
   echo "Hotfix in master" >> file.txt
   git commit -a -m "Hotfix commit in master"
   ```

2. Перебазируйте ветку `feature` относительно `master`:
   ```bash
   git checkout feature
   git rebase master
   ```

3. Проверьте результат с помощью команды `git log` и убедитесь, что история стала линейной.

### Шаг 3: Решение конфликтов при перебазировании
1. Сделайте ещё один коммит в основной ветке:
   ```bash
   git checkout master
   echo "Another change in master" >> file.txt
   git commit -a -m "Another commit in master"
   ```

2. Перебазируйте ветку `feature` и решите конфликт:
   ```bash
   git checkout feature
   git rebase master
   ```

3. Разрешите конфликт в файле, добавьте изменения и продолжите перебазирование:
   ```bash
   git add file.txt
   git rebase --continue
   ```

### Шаг 4: Опасности перебазирования
1. Перебазируйте ветку, которая уже была отправлена в удалённый репозиторий (при необходимости создайте тестовый удалённый репозиторий).
2. Поймите, почему перебазирование публичных веток может привести к проблемам для других участников проекта.

### Дополнительные задания:
1. Используйте опцию `--onto` для перебазирования ветки на другую ветку.
2. Настройте Git так, чтобы по умолчанию при выполнении `git pull` использовалось перебазирование.

## Вопросы для самопроверки:
1. Чем отличается перебазирование от слияния?
2. Как разрешить конфликты при перебазировании?
3. Почему не рекомендуется перебазировать коммиты, которые уже были отправлены в публичный репозиторий?

## Ожидаемый результат:
- Вы должны научиться эффективно использовать перебазирование для упрощения истории коммитов, а также понимать, в каких ситуациях это действие может быть рискованным.