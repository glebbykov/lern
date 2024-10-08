
# Лабораторная работа №10: Расширенное использование ролей в Ansible

## Цель работы
Изучить расширенные возможности работы с ролями в Ansible, включая создание зависимостей между ролями, использование динамических переменных, оптимизацию задач и написание тестов для ролей.

## Задачи
1. Изучить работу с зависимостями ролей.
2. Научиться использовать динамические переменные и факты в ролях.
3. Изучить методы оптимизации сценариев и предотвращения повторного выполнения задач.
4. Рассмотреть тестирование ролей с помощью Molecule.

## Описание работы

### 1. Зависимости ролей
Ansible позволяет указать зависимости одной роли от других ролей. Это делается через файл `meta/main.yml`. Пример:

```yaml
# roles/web/meta/main.yml
dependencies:
  - { role: ntp, ntp_server: "pool.ntp.org" }
  - { role: firewall }
```

Задача: реализовать роли с зависимостями, например, роль для настройки Nginx, которая зависит от настройки брандмауэра и синхронизации времени через NTP.

### 2. Использование динамических переменных и фактов
Ansible позволяет использовать динамические переменные и факты, которые собираются с удалённых хостов. Это позволяет адаптировать сценарии к конкретным условиям. Пример использования:

```yaml
# Использование динамического факта
- name: Настроить приложение на основе операционной системы
  template:
    src: "{{ ansible_distribution }}.j2"
    dest: /etc/myapp/config
```

Задача: написать роль, которая адаптируется к различным операционным системам и настраивает сервис в зависимости от версии ОС.

### 3. Оптимизация сценариев с помощью кеширования фактов
Факты, собираемые Ansible, можно кэшировать для ускорения выполнения сценариев. Кэширование настроек фактов позволяет сократить время выполнения при повторных запусках. Настройка кэширования:

```yaml
# Включение кэширования в ansible.cfg
[defaults]
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_cache
fact_caching_timeout = 86400
```

Задача: включить кэширование фактов в вашем сценарии и проверить его работу.

### 4. Тестирование ролей с использованием Molecule
Для тестирования ролей Ansible используется инструмент Molecule, который позволяет развернуть тестовое окружение, выполнить сценарии и проверить результат. Пример команды для запуска тестов:

```bash
molecule test
```

Задача: настроить Molecule для тестирования созданных вами ролей.

## Дополнительные задания
1. Добавьте в роли использование динамических переменных и адаптацию к различным версиям ОС.
2. Настройте кэширование фактов и убедитесь в уменьшении времени выполнения сценариев при повторных запусках.
3. Реализуйте тестирование ролей с использованием Molecule и опишите шаги тестирования.

## Вопросы для самопроверки

1. Как определить зависимости ролей и зачем они нужны?
2. Что такое динамические переменные в Ansible и как они могут быть использованы в сценариях?
3. Какие методы оптимизации сценариев существуют в Ansible?
4. Как работает кэширование фактов в Ansible и в каких ситуациях оно полезно?
5. Как используется Molecule для тестирования ролей, и какие основные команды для этого нужны?
