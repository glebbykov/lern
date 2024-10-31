
# Лабораторная работа №19: Верификаторы для Ansible с использованием Molecule

## Цель работы:
Познакомиться с инструментами для проверки успешного выполнения Ansible ролей, такими как встроенный верификатор Ansible, а также сторонние верификаторы Goss и TestInfra, и их интеграцией в Molecule.

## Задания:

### 1. Проверка с использованием встроенного Ansible верификатора
1. Создайте файл `verify.yml` в каталоге `molecule/default` и добавьте задачи проверки для роли, используя модули `assert`, `package_facts`, `service_facts` и другие, чтобы убедиться, что роль выполнилась успешно.
2. Запустите проверку командой:
   ```bash
   molecule verify
   ```

### 2. Установка и настройка Goss
1. Установите `molecule-goss` с помощью pip:
   ```bash
   pip install molecule-goss
   ```
2. Создайте новый сценарий для проверки с Goss:
   ```bash
   molecule init scenario -r ssh --driver-name docker --verifier-name goss
   ```
3. Создайте файл `test_sshd.yml` в каталоге `molecule/goss/tests/` и добавьте проверки, такие как:
   ```yaml
   file:
     /etc/ssh/ssh_host_ed25519_key.pub:
       exists: true
       mode: '0644'
       owner: root
       group: root
   service:
     sshd:
       enabled: true
       running: true
   ```
4. Запустите проверку командой `molecule verify` и проверьте результаты.

### 3. Установка и настройка TestInfra
1. Установите `pytest-testinfra` с помощью pip:
   ```bash
   pip install pytest-testinfra
   ```
2. Создайте сценарий с TestInfra:
   ```bash
   molecule init scenario -r ssh --driver-name docker --verifier-name testinfra
   ```
3. Создайте файл `test_default.py` в каталоге `molecule/testinfra/tests/` и добавьте тесты, например:
   ```python
   import os
   import testinfra.utils.ansible_runner
   
   testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
       os.environ["MOLECULE_INVENTORY_FILE"]
   ).get_hosts("all")
   
   def test_sshd_is_installed(host):
       sshd = host.package("openssh-server")
       assert sshd.is_installed
   
   def test_sshd_running_and_enabled(host):
       sshd = host.service("sshd")
       assert sshd.is_running
       assert sshd.is_enabled
   ```
4. Запустите проверку командой `molecule verify` и убедитесь, что все тесты прошли успешно.

## Дополнительные задания:

### Дополнительное задание 1: Создание дополнительных тестов для Goss
1. Расширьте файл `test_sshd.yml`, добавив проверки на конфигурацию сети и тесты для других сервисов, таких как Nginx или Apache.
2. Запустите проверку с помощью Goss и проанализируйте результаты.

### Дополнительное задание 2: Создание сложных проверок с TestInfra
1. Добавьте тесты в `test_default.py`, чтобы проверить доступность сетевых портов и состояние дополнительных пакетов.
2. Настройте тесты для проверки привязки процессов к определенным пользователям и группам.

### Дополнительное задание 3: Автоматизация запуска верификаторов через CI/CD
1. Настройте запуск Molecule с использованием Goss и TestInfra в вашей CI/CD среде (например, GitLab CI или GitHub Actions).
2. Настройте триггеры для запуска проверок при каждом коммите или перед слиянием изменений в основную ветку.

## Вопросы для закрепления:
1. Какую задачу выполняют верификаторы в Molecule?
2. В чем преимущества использования Goss для проверки?
3. Почему TestInfra позволяет гибче проверять состояние сервера?
4. Как Molecule использует `verify.yml` для встроенной проверки?
5. Как можно объединить несколько верификаторов для комплексной проверки?
