# Минимальный веб-сервер на Go

```go
package main

import (
        "fmt"
        "net/http"
)

func hello(w http.ResponseWriter, _ *http.Request) {
        fmt.Fprintf(w, "Hello")
}

func main() {
        http.HandleFunc("/", hello)
        http.ListenAndServe("0.0.0.0:8080", nil)
}
```

# Установка Go версии 1.23.4 для Linux

## Шаги установки

1. **Скачайте архив с Go:**

   ```bash
   wget https://go.dev/dl/go1.23.4.linux-amd64.tar.gz
   ```

2. **Проверьте целостность архива (рекомендуется):**

   Сравните SHA256-хеш скачанного файла с официальным значением, чтобы убедиться в его целостности.

   ```bash
   sha256sum go1.23.4.linux-amd64.tar.gz
   ```

   Официальное значение SHA256 для этой версии можно найти на странице загрузок Go.

3. **Удалите предыдущую версию Go (если установлена):**

   ```bash
   sudo rm -rf /usr/local/go
   ```

4. **Распакуйте архив в `/usr/local`:**

   ```bash
   sudo tar -C /usr/local -xzf go1.23.4.linux-amd64.tar.gz
   ```

5. **Добавьте Go в переменную окружения PATH:**

   Добавьте следующую строку в файл `~/.profile` или `~/.bash_profile`:

   ```bash
   export PATH=$PATH:/usr/local/go/bin
   ```

   Затем примените изменения:

   ```bash
   source ~/.profile
   ```

   или просто сделайте export:

   ```bash
   export PATH=$PATH:/usr/local/go/bin
   ```

6. **Проверьте установку:**

   ```bash
   go version
   ```

   Вы должны увидеть что-то подобное:

   ```bash
   go version go1.23.4 linux/amd64
   ```

## Запуск веб-сервера

1. **Создайте файл с кодом веб-сервера:**

   Сохраните один из приведённых выше кодов в файл `webserver.go`.

2. **Запустите сервер с помощью команды:**

   ```bash
   go run webserver.go
   ```

   Сервер запустится и будет доступен по адресу:

   ```
   http://localhost:8080
   ```

3. **Тестируйте сервер:**

   - Для минимальной версии:

     ```bash
     curl http://localhost:8080
     ```

     Вы должны увидеть ответ:

     ```
     Hello
     ```

# Практическое задание: Настройка изолированного сетевого моста

## Цель
Настроить сетевой мост в Linux для взаимодействия контейнеров, виртуальных машин или других изолированных сред без изменения конфигурации основного интерфейса.

## Шаги настройки

1. **Создайте сетевой мост:**

   Добавьте новый bridge-интерфейс с именем `br0`:

   ```bash
   sudo ip link add br0 type bridge
   sudo ip link set br0 up
   ```

2. **Создайте виртуальные интерфейсы veth:**

   Создайте пару виртуальных Ethernet-интерфейсов:

   ```bash
   sudo ip link add veth1 type veth peer name veth2
   ```

3. **Подключите один из виртуальных интерфейсов к мосту:**

   ```bash
   sudo ip link set veth1 master br0
   sudo ip link set veth1 up
   sudo ip link set veth2 up
   ```

4. **Назначьте IP-адреса для тестирования:**

   Назначьте IP-адреса для моста и одного из виртуальных интерфейсов:

   ```bash
   sudo ip addr add 192.168.1.1/24 dev br0
   sudo ip addr add 192.168.1.2/24 dev veth2
   ```

5. **Проверьте связь между интерфейсами:**

   Убедитесь, что связь между `br0` и `veth2` установлена:

   ```bash
   ping -c 4 192.168.1.1 -I veth2
   ```

6. **Используйте мост для контейнеров или виртуальных машин:**

   Мост `br0` теперь доступен для подключения виртуальных машин, контейнеров или сетевых пространств имён.

7. **Дополнительно: Тестирование с пространствами имён:**

   Создайте два пространства имён и подключите их через виртуальные интерфейсы `veth`:

   ```bash
   sudo ip netns add net1
   sudo ip netns add net2
   sudo ip link set veth1 netns net1
   sudo ip link set veth2 netns net2
   ```

   Назначьте IP-адреса виртуальным интерфейсам в каждом пространстве имён:

   ```bash
   sudo ip netns exec net1 ip addr add 192.168.1.3/24 dev veth1
   sudo ip netns exec net1 ip link set veth1 up
   sudo ip netns exec net2 ip addr add 192.168.1.4/24 dev veth2
   sudo ip netns exec net2 ip link set veth2 up
   ```

   Проверьте связь между пространствами имён:

   ```bash
   sudo ip netns exec net1 ping -c 4 192.168.1.4
   ```

Этот подход изолирует мостовую сеть от основного интерфейса, сохраняя доступ к серверу через основной сетевой интерфейс.
