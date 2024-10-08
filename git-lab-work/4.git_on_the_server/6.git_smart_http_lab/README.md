
# Лабораторная работа 6: Настройка Умного HTTP в Git

## Цель:
Научиться настраивать умный HTTP для работы с Git, предоставляющий как доступ с аутентификацией, так и без неё, через сервер CGI с использованием скрипта git-http-backend.

## Теоретическая часть:
Умный HTTP позволяет настроить доступ к Git-репозиториям через HTTP(S), предоставляя анонимный доступ на чтение и аутентифицированный доступ для записи. Это удобно для использования в проектах с различными уровнями доступа.

## Шаги для выполнения:

### Шаг 1: Установка Apache и необходимых модулей
1. Установите Apache и необходимые модули:
   ```bash
   sudo apt-get install apache2 apache2-utils
   sudo a2enmod cgi alias env
   ```

### Шаг 2: Настройка прав доступа к репозиториям
1. Назначьте пользователя и группу для каталога репозиториев:
   ```bash
   sudo chgrp -R www-data /srv/git
   ```

### Шаг 3: Настройка Apache для работы с git-http-backend
1. Добавьте следующие настройки в конфигурационный файл Apache:
   ```
   SetEnv GIT_PROJECT_ROOT /srv/git
   SetEnv GIT_HTTP_EXPORT_ALL
   ScriptAlias /git/ /usr/lib/git-core/git-http-backend/
   ```

### Шаг 4: Настройка аутентификации пользователей
1. Добавьте в конфигурацию Apache блок для аутентификации пользователей:
   ```
   <Files "git-http-backend">
       AuthType Basic
       AuthName "Git Access"
       AuthUserFile /srv/git/.htpasswd
       Require expr !(%{QUERY_STRING} -strmatch '*service=git-receive-pack*' || %{REQUEST_URI} =~ m#/git-receive-pack$#)
       Require valid-user
   </Files>
   ```

2. Создайте файл с паролями пользователей для аутентификации:
   ```bash
   htpasswd -c /srv/git/.htpasswd schacon
   ```

### Шаг 5: Тестирование HTTP-доступа к репозиториям
1. Попробуйте клонировать репозиторий через HTTP:
   ```bash
   git clone http://your_server/git/project.git
   ```

2. Попробуйте отправить изменения с аутентификацией:
   ```bash
   git push http://your_server/git/project.git
   ```

### Дополнительные задания:
1. Настройте SSL для шифрования соединений с сервером.
2. Настройте различные уровни доступа к репозиториям для разных пользователей.

## Вопросы для самопроверки:
1. Какие преимущества предоставляет умный HTTP для работы с Git-репозиториями?
2. Как настроить аутентификацию пользователей для записи в репозитории через HTTP?
3. В каких случаях стоит использовать умный HTTP вместо SSH или Git-демона?

## Ожидаемый результат:
- Вы должны научиться настраивать умный HTTP для Git, обеспечивать анонимный доступ на чтение и аутентифицированный доступ для записи.
