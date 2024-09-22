
# Ansible Lab - Multiline String Handling

### Страницы 56-66

Эта лабораторная работа посвящена тому, как работать с многострочными строковыми значениями в YAML, что является важным аспектом при написании сценариев Ansible. В YAML есть несколько способов работы с многострочными строками с использованием операторных скобок и специальных символов.

### Многострочные строковые значения в YAML

YAML поддерживает многострочные строки, которые можно задавать с помощью операторов `|` и `>`. Эти операторы также позволяют использовать символы, указывающие на сохранение отступов и разрывов строк. Пример использования вертикальной черты и знака плюс `|+` для сохранения разрывов строк:

```yaml
visiting_address: |+
  Department of Computer Science
  A.V. Williams Building
  University of Maryland
city: College Park
state: Maryland
```

Этот формат сохраняет все разрывы строк так, как они указаны.

В JSON многострочные строки не поддерживаются, поэтому разрывы строк должны быть заменены на `\n` или переданы в виде массива:

```json
{
  "visiting_address": ["Department of Computer Science", "A.V. Williams Building", "University of Maryland"],
  "city": "College Park",
  "state": "Maryland"
}
```

### Практика

1. Создайте плейбук `multiline_strings.yml`, который будет использовать многострочные строки для конфигурации сервера.

2. В этом плейбуке создайте задачу, которая использует модуль `copy` для копирования многострочного файла на целевой сервер.

#### Пример: multiline_strings.yml

```yaml
---
- name: Copy multiline string to a file
  hosts: all
  become: true
  tasks:
    - name: Create file with multiline content
      copy:
        content: |
          Department of Computer Science
          A.V. Williams Building
          University of Maryland
          City: College Park
          State: Maryland
        dest: /tmp/multiline_address.txt
```

3. Запустите этот плейбук с помощью команды:

```bash
ansible-playbook multiline_strings.yml
```

4. Проверьте, что файл был создан на целевом сервере и содержит нужный текст:

```bash
cat /tmp/multiline_address.txt
```

Этот файл должен содержать текст с разрывами строк, как указано в плейбуке.

При написании сценариев Ansible часто возникает необходимость передавать аргументы модулям. Для лучшей читаемости и уменьшения ошибок предпочтительно передавать аргументы в формате YAML, а не в виде одной строки. Это позволяет легче анализировать ошибки и упрощает структуру сценария.

### Пример: Использование аргументов в одной строке

При использовании модуля `package` аргументы можно передать в виде одной строки. Например:

```yaml
- name: Ensure nginx is installed
  package: name=nginx update_cache=true
```

Этот способ удобен для командной строки, но при написании плейбуков для больших сценариев этот стиль становится менее удобным.

### Предпочтительный стиль: Чистый YAML

Для улучшенной читабельности и возможности использования инструментов для анализа, таких как `yamllint`, рекомендуется использовать чистый формат YAML:

```yaml
- name: Ensure nginx is installed
  package:
    name: nginx
    update_cache: true
```

### Пример сценария: webservers2.yml

Ниже приведен пример плейбука, который устанавливает и настраивает веб-сервер Nginx с использованием лучшего стиля передачи аргументов в формате YAML.

```yaml
---
- name: Configure webserver with nginx
  hosts: webservers
  become: true
  tasks:
    - name: Ensure nginx is installed
      package:
        name: nginx
        update_cache: true

    - name: Copy nginx config file
      copy:
        src: nginx.conf
        dest: /etc/nginx/sites-available/default

    - name: Enable configuration
      file:
        src: /etc/nginx/sites-available/default
        dest: /etc/nginx/sites-enabled/default
        state: link

    - name: Copy home page template
      template:
        src: index.html.j2
        dest: /usr/share/nginx/html/index.html

    - name: Restart nginx
      service:
        name: nginx
        state: restarted
```

### Операции и задачи

Каждая операция должна содержать переменную `hosts`, которая определяет, к каким хостам будут применяться задачи. Например, в приведённом сценарии все задачи применяются к группе хостов `webservers`. 

Пример одной из задач:

```yaml
- name: Ensure nginx is installed
  package:
    name: nginx
    update_cache: true
```

Эта задача использует модуль `package` для установки веб-сервера Nginx.

### Модули Ansible

В этом сценарии используются следующие модули:

- **package**: для установки и удаления пакетов.
- **copy**: для копирования файлов на сервер.
- **file**: для управления атрибутами файлов и символических ссылок.
- **service**: для управления службами.
- **template**: для создания файлов на основе шаблонов и их копирования на сервер.

### Практическое задание

1. Создайте плейбук с именем `webservers2.yml`, который настроит веб-сервер Nginx на вашем сервере. 
2. Используйте модули `package`, `copy`, `file`, `service`, и `template`, чтобы выполнить следующие задачи:
    - Установите Nginx.
    - Скопируйте конфигурационный файл Nginx на сервер.
    - Настройте символическую ссылку для конфигурационного файла.
    - Скопируйте файл `index.html` в директорию `/usr/share/nginx/html`.
    - Перезапустите Nginx.

3. После создания плейбука запустите его с помощью команды:

```bash
ansible-playbook webservers2.yml
```

4. Проверьте, что Nginx запущен и доступен по вашему адресу (например, по `http://localhost`).

### Документация по модулям

Используйте утилиту `ansible-doc`, чтобы получить документацию по использованию модулей Ansible. Например:

```bash
$ ansible-doc service
```

### Заключение

Эта лабораторная работа показала, как правильно передавать аргументы в Ansible с использованием чистого YAML-формата, а также как настроить веб-сервер Nginx с использованием различных модулей. Следуя этим рекомендациям, вы сможете создавать более читаемые и поддерживаемые плейбуки.
