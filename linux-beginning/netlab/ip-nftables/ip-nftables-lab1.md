# iptables / nftables - Практическая лабораторная работа

**Фильтрация, NAT, stateful inspection, логирование, rate limiting - полный курс на живой сети из namespace'ов**

---

## Обзор лабораторной

В этой лабораторной ты построишь виртуальную сеть из namespace'ов (как в предыдущей работе по Linux Bridge) и на ней отработаешь все ключевые возможности iptables и nftables: фильтрацию трафика, NAT, stateful inspection, логирование, rate limiting, защиту от сканирования портов и брутфорса. В конце - переход на nftables как современную замену iptables.

## Что ты построишь

```
                        Internet
                            │
                       ┌────┴────┐
                       │  Host   │
                       │ (router │
                       │  + fw)  │
                       └────┬────┘
                            │
           ┌────────────────┼────────────────┐
           │          br0 (bridge)           │
           │          10.0.0.1/24            │
           └───┬────────┬────────┬───────────┘
               │        │        │
          veth-web  veth-app  veth-db
               │        │        │
        ┌──────┴──┐ ┌───┴─────┐ ┌┴───────────┐
        │   web   │ │   app   │ │    db      │
        │ .2/24   │ │ .3/24   │ │  .4/24     │
        │ HTTP:80 │ │ APP:8080│ │ MySQL:3306 │
        │ SSH:22  │ │ SSH:22  │ │ SSH:22     │
        └─────────┘ └─────────┘ └────────────┘
```

Три namespace имитируют реальные серверы: **web** (фронтенд), **app** (бэкенд), **db** (база данных). Ты настроишь firewall-правила, соответствующие типичной production-среде.

## Что нужно

- Linux VM (Ubuntu 20.04+, Debian 11+)
- Root-доступ (`sudo`)
- Пакеты: `iproute2`, `iptables`, `nftables`, `ncat`, `tcpdump`, `curl`

```bash
sudo apt-get update
sudo apt-get install -y iproute2 iptables nftables ncat tcpdump curl conntrack
```

## Ключевые концепции

| Концепция | Описание |
|-----------|----------|
| **iptables** | Утилита управления Netfilter - фреймворком фильтрации пакетов в ядре Linux |
| **Таблицы (tables)** | `filter` (фильтрация), `nat` (трансляция адресов), `mangle` (модификация пакетов), `raw` (до conntrack) |
| **Цепочки (chains)** | `INPUT` (входящие на хост), `OUTPUT` (исходящие от хоста), `FORWARD` (транзитные), `PREROUTING`, `POSTROUTING` |
| **Targets** | `ACCEPT`, `DROP`, `REJECT`, `LOG`, `SNAT`, `DNAT`, `MASQUERADE` |
| **Conntrack** | Отслеживание состояния соединений: NEW, ESTABLISHED, RELATED, INVALID |
| **nftables** | Замена iptables с единым синтаксисом, атомарными обновлениями, лучшей производительностью |

---

## Часть 0: Подготовка сети

---

### Задание 0: Создание инфраструктуры

**Цель:** развернуть сеть из трёх namespace'ов, подключённых к bridge. Это фундамент для всех последующих заданий.

**Шаг 1.** Очисти предыдущие конфигурации (если есть):

```bash
# Удалить namespace'ы если остались от прошлой лабы
for NS in web app db red blue green; do
    sudo ip netns del $NS 2>/dev/null
done
sudo ip link del br0 2>/dev/null
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -F FORWARD
```

**Шаг 2.** Создай bridge:

```bash
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip addr add 10.0.0.1/24 dev br0
```

**Шаг 3.** Создай три namespace и подключи к bridge:

```bash
for NS in web app db; do
    sudo ip netns add $NS
    sudo ip netns exec $NS ip link set lo up

    sudo ip link add veth-$NS type veth peer name eth0-$NS
    sudo ip link set veth-$NS master br0
    sudo ip link set veth-$NS up
    sudo ip link set eth0-$NS netns $NS
done
```

**Шаг 4.** Назначь IP-адреса:

```bash
sudo ip netns exec web ip addr add 10.0.0.2/24 dev eth0-web
sudo ip netns exec web ip link set eth0-web up
sudo ip netns exec web ip route add default via 10.0.0.1

sudo ip netns exec app ip addr add 10.0.0.3/24 dev eth0-app
sudo ip netns exec app ip link set eth0-app up
sudo ip netns exec app ip route add default via 10.0.0.1

sudo ip netns exec db ip addr add 10.0.0.4/24 dev eth0-db
sudo ip netns exec db ip link set eth0-db up
sudo ip netns exec db ip route add default via 10.0.0.1
```

**Шаг 5.** Включи IP forwarding и базовый NAT:

```bash
sudo sysctl -w net.ipv4.ip_forward=1

# Определи внешний интерфейс
EXT_IF=$(ip route show default | awk '{print $5}')
echo "Внешний интерфейс: $EXT_IF"

sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o $EXT_IF -j MASQUERADE
sudo iptables -A FORWARD -i br0 -o $EXT_IF -j ACCEPT
sudo iptables -A FORWARD -i $EXT_IF -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i br0 -o br0 -j ACCEPT
```

**Шаг 6.** Проверь связность:

```bash
# Namespace'ы видят друг друга
sudo ip netns exec web ping -c 1 10.0.0.3
sudo ip netns exec web ping -c 1 10.0.0.4
sudo ip netns exec app ping -c 1 10.0.0.2

# Namespace'ы видят хост
sudo ip netns exec web ping -c 1 10.0.0.1

# Namespace'ы видят интернет
sudo ip netns exec web ping -c 1 8.8.8.8
```

**Шаг 7.** Запусти «сервисы» в каждом namespace:

```bash
# Web-сервер (HTTP на порту 80)
sudo ip netns exec web sh -c '
    while true; do
        echo -e "HTTP/1.1 200 OK\r\nContent-Length: 22\r\n\r\nHello from web server!" | ncat -l -p 80 2>/dev/null
    done &'

# App-сервер (на порту 8080)
sudo ip netns exec app sh -c '
    while true; do
        echo -e "HTTP/1.1 200 OK\r\nContent-Length: 22\r\n\r\nHello from app server!" | ncat -l -p 8080 2>/dev/null
    done &'

# «MySQL» (на порту 3306)
sudo ip netns exec db sh -c '
    while true; do
        echo "MySQL ready" | ncat -l -p 3306 2>/dev/null
    done &'

# SSH-имитация на всех трёх (порт 22)
for NS in web app db; do
    sudo ip netns exec $NS sh -c '
        while true; do
            echo "SSH-mock" | ncat -l -p 22 2>/dev/null
        done &'
done
```

**Шаг 8.** Убедись, что сервисы работают:

```bash
sudo ip netns exec app curl -s 10.0.0.2:80
sudo ip netns exec web curl -s 10.0.0.3:8080
sudo ip netns exec app ncat -z -v 10.0.0.4 3306
```

Если всё отвечает - инфраструктура готова. Переходим к firewall.

---

## Часть 1: Основы iptables

---

### Задание 1: Структура iptables - таблицы, цепочки, правила

**Цель:** понять архитектуру iptables и научиться читать/добавлять/удалять правила.

**Шаг 1.** Посмотри все существующие правила на хосте:

```bash
# Таблица filter (по умолчанию)
sudo iptables -L -n -v --line-numbers

# Таблица nat
sudo iptables -t nat -L -n -v --line-numbers

# Таблица mangle
sudo iptables -t mangle -L -n -v --line-numbers

# Таблица raw
sudo iptables -t raw -L -n -v --line-numbers
```

> **❓ Вопрос:** Ты видишь цепочки INPUT, FORWARD, OUTPUT в таблице filter и PREROUTING, POSTROUTING в nat. Почему в filter нет PREROUTING? Через какие цепочки проходит пакет, идущий транзитом (от namespace к интернету)?

**Шаг 2.** Посмотри правила внутри namespace web:

```bash
sudo ip netns exec web iptables -L -n -v --line-numbers
```

Пусто - у каждого namespace свои iptables, изолированные от хоста.

**Шаг 3.** Разберись с порядком прохождения пакета. Путь транзитного пакета (namespace → интернет):

```
Пакет из namespace
       │
       ▼
┌─────────────┐
│ PREROUTING  │  (raw → mangle → nat)
└──────┬──────┘
       │
  Routing decision: пакет не для хоста → FORWARD
       │
       ▼
┌─────────────┐
│   FORWARD   │  (mangle → filter)
└──────┬──────┘
       │
       ▼
┌──────────────┐
│ POSTROUTING  │  (mangle → nat)
└──────┬───────┘
       │
       ▼
   Уходит наружу
```

Путь пакета, адресованного хосту:

```
Пакет на хост
       │
       ▼
┌─────────────┐
│ PREROUTING  │
└──────┬──────┘
       │
  Routing decision: пакет для хоста → INPUT
       │
       ▼
┌─────────────┐
│    INPUT    │
└──────┬──────┘
       │
       ▼
   Приложение
```

**Шаг 4.** Научись управлять правилами - базовые операции:

```bash
# -A (Append) - добавить в конец цепочки
sudo iptables -A INPUT -p icmp -j ACCEPT

# -I (Insert) - вставить в начало (или на позицию N)
sudo iptables -I INPUT 1 -p tcp --dport 22 -j ACCEPT

# -D (Delete) - удалить по номеру
sudo iptables -D INPUT 1

# -D (Delete) - удалить по спецификации
sudo iptables -D INPUT -p icmp -j ACCEPT

# -R (Replace) - заменить правило по номеру
# sudo iptables -R INPUT 1 -p tcp --dport 22 -j DROP

# -F (Flush) - удалить все правила в цепочке
sudo iptables -F INPUT

# -Z (Zero) - обнулить счётчики
sudo iptables -Z

# -P (Policy) - изменить политику по умолчанию
# sudo iptables -P INPUT DROP   # осторожно! заблокирует всё
```

Посмотри текущее состояние после манипуляций:

```bash
sudo iptables -L -n -v --line-numbers
```

> **❓ Вопрос:** Порядок правил критически важен - iptables проходит их сверху вниз и применяет первое совпавшее. Если правило `DROP all` стоит выше `ACCEPT ssh`, что произойдёт с SSH-пакетом?

---

### Задание 2: Фильтрация на хосте - защита INPUT

**Цель:** настроить firewall на хосте (bridge/router) по принципу «запрещено всё, что не разрешено явно» (default deny).

**Шаг 1.** Сначала сохрани текущие правила (чтобы можно было откатиться):

```bash
sudo iptables-save > /tmp/iptables-backup.rules
cat /tmp/iptables-backup.rules
```

**Шаг 2.** Очисти цепочку INPUT (NAT и FORWARD оставим):

```bash
sudo iptables -F INPUT
```

**Шаг 3.** Построй INPUT firewall по шагам:

```bash
# 1. Разрешить loopback (localhost-трафик)
sudo iptables -A INPUT -i lo -j ACCEPT

# 2. Разрешить уже установленные соединения
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 3. Разрешить ICMP (ping) - но не более 5 запросов в секунду
sudo iptables -A INPUT -p icmp --icmp-type echo-request \
    -m limit --limit 5/sec --limit-burst 10 -j ACCEPT

# 4. Разрешить SSH (порт 22) только от namespace'ов
sudo iptables -A INPUT -s 10.0.0.0/24 -p tcp --dport 22 -j ACCEPT

# 5. Разрешить DNS-ответы (если хост выступает резолвером)
sudo iptables -A INPUT -p udp --sport 53 -j ACCEPT

# 6. Установить политику по умолчанию - DROP
sudo iptables -P INPUT DROP
```

**Шаг 4.** Проверь:

```bash
# Ping из namespace - работает (правило 3)
sudo ip netns exec web ping -c 2 10.0.0.1

# Curl из namespace на несуществующий сервис хоста - дропается
sudo ip netns exec web curl -s --connect-timeout 2 10.0.0.1:12345
echo "Exit code: $?"

# Посмотри счётчики - какие правила сработали
sudo iptables -L INPUT -n -v --line-numbers
```

**Шаг 5.** Изучи разницу между DROP и REJECT:

```bash
# Добавим временное правило REJECT для порта 12345
sudo iptables -I INPUT 6 -p tcp --dport 12345 -j REJECT --reject-with tcp-reset

# Из namespace - теперь получим мгновенный отказ, а не таймаут
sudo ip netns exec web curl -s --connect-timeout 2 10.0.0.1:12345
echo "Exit code: $?"
```

```bash
# Удали тестовое правило
sudo iptables -D INPUT -p tcp --dport 12345 -j REJECT --reject-with tcp-reset
```

> **❓ Вопрос:** DROP молча отбрасывает пакет, REJECT отправляет ответ (RST или ICMP unreachable). Что лучше для внешнего firewall? А для внутренней сети? Подсказка: подумай о сканировании портов и о быстроте обнаружения проблем.

---

### Задание 3: Фильтрация FORWARD - межсерверный firewall

**Цель:** настроить правила пересылки между namespace'ами: web может ходить в app, app может ходить в db, но web НЕ может ходить в db напрямую (трёхуровневая архитектура).

**Шаг 1.** Очисти цепочку FORWARD и начни с чистого листа:

```bash
# Сохрани NAT-правила, очисти только filter FORWARD
sudo iptables -F FORWARD
```

**Шаг 2.** Построй FORWARD firewall:

```bash
# 1. Разрешить уже установленные соединения
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# 2. web -> app: разрешить HTTP (8080)
sudo iptables -A FORWARD -s 10.0.0.2 -d 10.0.0.3 -p tcp --dport 8080 -j ACCEPT

# 3. app -> db: разрешить MySQL (3306)
sudo iptables -A FORWARD -s 10.0.0.3 -d 10.0.0.4 -p tcp --dport 3306 -j ACCEPT

# 4. Разрешить ICMP между всеми namespace'ами (для диагностики)
sudo iptables -A FORWARD -s 10.0.0.0/24 -d 10.0.0.0/24 -p icmp -j ACCEPT

# 5. Разрешить namespace'ам выход в интернет
EXT_IF=$(ip route show default | awk '{print $5}')
sudo iptables -A FORWARD -i br0 -o $EXT_IF -j ACCEPT
sudo iptables -A FORWARD -i $EXT_IF -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# 6. Всё остальное - DROP
sudo iptables -P FORWARD DROP
```

**Шаг 3.** Проверь, что трёхуровневая модель работает:

```bash
# web -> app:8080 - РАЗРЕШЕНО
sudo ip netns exec web curl -s --connect-timeout 2 10.0.0.3:8080
echo "--- Ожидаем: Hello from app server! ---"

# app -> db:3306 - РАЗРЕШЕНО
sudo ip netns exec app ncat -z -v -w 2 10.0.0.4 3306
echo "--- Ожидаем: succeeded ---"

# web -> db:3306 - ЗАБЛОКИРОВАНО
sudo ip netns exec web ncat -z -v -w 2 10.0.0.4 3306
echo "--- Ожидаем: timeout / refused ---"

# web -> app:22 (SSH) - ЗАБЛОКИРОВАНО (разрешён только 8080)
sudo ip netns exec web ncat -z -v -w 2 10.0.0.3 22
echo "--- Ожидаем: timeout ---"

# Ping работает между всеми (правило 4)
sudo ip netns exec web ping -c 1 10.0.0.4
echo "--- Ожидаем: ping OK ---"
```

**Шаг 4.** Посмотри, какие правила сработали и сколько пакетов поймали:

```bash
sudo iptables -L FORWARD -n -v --line-numbers
```

> **❓ Вопрос:** web не может подключиться к db:3306, но ping (ICMP) до db работает. Почему правило ICMP ACCEPT не «пробивает» защиту MySQL? На каком уровне работает разделение?

---

### Задание 4: Фильтрация внутри namespace - iptables на «сервере»

**Цель:** настроить firewall непосредственно на «сервере» db - как если бы это был реальный MySQL-сервер с iptables.

**Шаг 1.** Зайди в namespace db и посмотри текущее состояние:

```bash
sudo ip netns exec db iptables -L -n -v
```

**Шаг 2.** Настрой firewall внутри db:

```bash
# Разрешить loopback
sudo ip netns exec db iptables -A INPUT -i lo -j ACCEPT

# Разрешить установленные соединения
sudo ip netns exec db iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Разрешить MySQL ТОЛЬКО от app (10.0.0.3)
sudo ip netns exec db iptables -A INPUT -s 10.0.0.3 -p tcp --dport 3306 -j ACCEPT

# Разрешить SSH ТОЛЬКО от хоста (10.0.0.1) - для администрирования
sudo ip netns exec db iptables -A INPUT -s 10.0.0.1 -p tcp --dport 22 -j ACCEPT

# Разрешить ICMP от всех (для диагностики)
sudo ip netns exec db iptables -A INPUT -p icmp -j ACCEPT

# Всё остальное - DROP с логированием
sudo ip netns exec db iptables -A INPUT -j LOG --log-prefix "DB-DROPPED: " --log-level 4
sudo ip netns exec db iptables -A INPUT -j DROP
```

**Шаг 3.** Проверь:

```bash
# app -> db:3306 - РАЗРЕШЕНО
sudo ip netns exec app ncat -z -v -w 2 10.0.0.4 3306

# web -> db:3306 - ЗАБЛОКИРОВАНО (даже если FORWARD разрешал бы)
# Примечание: FORWARD уже блокирует, но db-firewall - вторая линия обороны
sudo ip netns exec web ncat -z -v -w 2 10.0.0.4 3306

# Посмотри логи заблокированных пакетов
sudo dmesg | grep "DB-DROPPED" | tail -5
```

**Шаг 4.** Настрой firewall внутри web:

```bash
# Разрешить loopback
sudo ip netns exec web iptables -A INPUT -i lo -j ACCEPT

# Разрешить установленные соединения
sudo ip netns exec web iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Разрешить HTTP отовсюду
sudo ip netns exec web iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Разрешить SSH только от хоста
sudo ip netns exec web iptables -A INPUT -s 10.0.0.1 -p tcp --dport 22 -j ACCEPT

# Разрешить ICMP
sudo ip netns exec web iptables -A INPUT -p icmp -j ACCEPT

# DROP всё остальное
sudo ip netns exec web iptables -A INPUT -j LOG --log-prefix "WEB-DROPPED: " --log-level 4
sudo ip netns exec web iptables -A INPUT -j DROP
```

**Шаг 5.** Проверь:

```bash
# HTTP работает
sudo ip netns exec app curl -s --connect-timeout 2 10.0.0.2:80

# SSH от app - заблокирован (разрешён только от хоста)
sudo ip netns exec app ncat -z -v -w 2 10.0.0.2 22

# Посмотри логи
sudo dmesg | grep "WEB-DROPPED" | tail -5
```

> **❓ Вопрос:** Зачем настраивать firewall И на роутере (FORWARD), И внутри namespace (INPUT)? Это избыточно? Подсказка: принцип defense in depth. Что будет, если кто-то получит доступ к app и попытается подключиться к db на порту, который не MySQL?

---

## Часть 2: Stateful Inspection - conntrack

---

### Задание 5: Состояния соединений

**Цель:** понять, как conntrack отслеживает состояния и почему stateful firewall надёжнее stateless.

**Шаг 1.** Установи (если ещё нет) и посмотри текущую таблицу conntrack:

```bash
sudo conntrack -L 2>/dev/null || echo "Установи conntrack: sudo apt install conntrack"
```

**Шаг 2.** Очисти conntrack и сгенерируй трафик:

```bash
# Очисти таблицу
sudo conntrack -F

# Пингани из web в app
sudo ip netns exec web ping -c 3 10.0.0.3

# Посмотри, что записал conntrack
sudo conntrack -L -p icmp
```

Ты увидишь что-то вроде:

```
icmp  1 29 src=10.0.0.2 dst=10.0.0.3 type=8 code=0 id=1234
         src=10.0.0.3 dst=10.0.0.2 type=0 code=0 id=1234 [ASSURED]
```

Это означает: conntrack знает, что на echo-request из 10.0.0.2 ожидается echo-reply из 10.0.0.3.

**Шаг 3.** Сгенерируй TCP-трафик и изучи состояния:

```bash
sudo conntrack -F

# HTTP-запрос
sudo ip netns exec web curl -s 10.0.0.3:8080

# Посмотри TCP-соединения
sudo conntrack -L -p tcp
```

Ты увидишь состояния TCP: `SYN_SENT`, `ESTABLISHED`, `TIME_WAIT` и т.д.

**Шаг 4.** Мониторь conntrack в реальном времени:

```bash
# Терминал 1: наблюдай за событиями conntrack
sudo conntrack -E
```

```bash
# Терминал 2: генерируй трафик
sudo ip netns exec web curl -s 10.0.0.3:8080
sudo ip netns exec web ping -c 1 10.0.0.4
```

Ты увидишь события `[NEW]`, `[UPDATE]`, `[DESTROY]` для каждого соединения.

**Шаг 5.** Посмотри статистику conntrack:

```bash
sudo conntrack -S
cat /proc/sys/net/netfilter/nf_conntrack_count
cat /proc/sys/net/netfilter/nf_conntrack_max
```

> **❓ Вопрос:** В наших правилах мы используем `-m state --state ESTABLISHED,RELATED`. Что означает состояние RELATED? Приведи пример трафика, который будет RELATED, но не ESTABLISHED. Подсказка: подумай про FTP, ICMP error, traceroute.

**Шаг 6.** Эксперимент: чем stateful лучше stateless?

```bash
# Stateless подход (ПЛОХО): разрешить все пакеты с source port 80
# Это то, как делали до conntrack - просто разрешали «ответы»
# sudo iptables -A FORWARD -p tcp --sport 80 -j ACCEPT
# Проблема: атакующий может отправить пакет с source port 80 и пройти firewall

# Stateful подход (ХОРОШО): разрешить только ESTABLISHED-соединения
# sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
# Только пакеты, принадлежащие уже установленному соединению, проходят
```

> **❓ Вопрос:** Почему stateless-правило `--sport 80 -j ACCEPT` опасно? Что может сделать атакующий, зная эту конфигурацию?

---

## Часть 3: Логирование и диагностика

---

### Задание 6: Логирование пакетов

**Цель:** научиться использовать LOG target для отладки и аудита firewall-правил.

**Шаг 1.** Добавь логирование заблокированного FORWARD-трафика (перед финальным DROP):

```bash
# Вставь правило LOG перед DROP (DROP - это политика, поэтому добавим в конец)
# Сначала узнай номер последнего правила
sudo iptables -L FORWARD -n --line-numbers

# Добавь логирование в конец (перед policy DROP)
sudo iptables -A FORWARD -j LOG \
    --log-prefix "FW-FORWARD-DROP: " \
    --log-level 4
```

**Шаг 2.** Сгенерируй заблокированный трафик:

```bash
# web -> db:3306 (заблокирован FORWARD)
sudo ip netns exec web ncat -z -v -w 2 10.0.0.4 3306 2>/dev/null

# web -> app:22 (заблокирован - разрешён только 8080)
sudo ip netns exec web ncat -z -v -w 2 10.0.0.3 22 2>/dev/null
```

**Шаг 3.** Прочитай логи:

```bash
sudo dmesg | grep "FW-FORWARD-DROP" | tail -10
```

Пример вывода:

```
FW-FORWARD-DROP: IN=br0 OUT=br0 SRC=10.0.0.2 DST=10.0.0.4 
    PROTO=TCP SPT=54321 DPT=3306 SYN
```

В логе видно: входящий интерфейс, исходящий, source/destination IP и порты, протокол, флаги TCP.

**Шаг 4.** Логируй с ограничением частоты (чтобы не забить лог):

```bash
# Удали старое правило без лимита
sudo iptables -D FORWARD -j LOG --log-prefix "FW-FORWARD-DROP: " --log-level 4

# Добавь с лимитом: максимум 10 записей в минуту
sudo iptables -A FORWARD -m limit --limit 10/min --limit-burst 5 \
    -j LOG --log-prefix "FW-FORWARD-DROP: " --log-level 4
```

**Шаг 5.** Полезный приём - логировать конкретный трафик для отладки:

```bash
# Логируем все NEW-соединения к db (для аудита: кто подключается)
sudo iptables -I FORWARD 3 -d 10.0.0.4 -m state --state NEW \
    -j LOG --log-prefix "DB-NEW-CONN: " --log-level 4

# Сгенерируй трафик
sudo ip netns exec app ncat -z -v -w 2 10.0.0.4 3306

# Посмотри лог
sudo dmesg | grep "DB-NEW-CONN" | tail -5
```

> **❓ Вопрос:** LOG не прерывает обработку - пакет продолжит идти по цепочке после LOG. Чем это отличается от DROP или ACCEPT? Почему LOG - не terminating target?

---

## Часть 4: Продвинутые сценарии

---

### Задание 7: Rate Limiting - защита от брутфорса и DDoS

**Цель:** ограничить частоту подключений для защиты от атак перебором и флуда.

**Шаг 1.** Ограничь SSH-подключения к web: не более 3 новых соединений в минуту:

```bash
# Добавь ПЕРЕД правилом, разрешающим SSH
# Сначала посмотри правила web
sudo ip netns exec web iptables -L INPUT -n --line-numbers

# Добавь rate limit для новых SSH-соединений
# (вставляем перед разрешающим правилом для SSH, если он есть)
sudo ip netns exec web iptables -I INPUT 3 -p tcp --dport 22 \
    -m state --state NEW \
    -m limit --limit 3/min --limit-burst 3 -j ACCEPT

# Заблокируй превышение лимита (вставь сразу после)
sudo ip netns exec web iptables -I INPUT 4 -p tcp --dport 22 \
    -m state --state NEW -j DROP
```

**Шаг 2.** Протестируй - попробуй «забрутфорсить» SSH:

```bash
# Быстро 10 раз подключиться к SSH web
for i in $(seq 1 10); do
    sudo ip netns exec app ncat -z -w 1 10.0.0.2 22 2>/dev/null
    echo "Attempt $i: exit code $?"
done
```

Первые 3 пройдут, остальные - DROP.

**Шаг 3.** Более умный подход - модуль `recent` для бана по IP:

```bash
# Очисти предыдущие rate-limit правила из web
sudo ip netns exec web iptables -F INPUT

# Пересоздай правила для web с модулем recent
sudo ip netns exec web iptables -A INPUT -i lo -j ACCEPT
sudo ip netns exec web iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH: если более 4 попыток за 60 секунд - бан
sudo ip netns exec web iptables -A INPUT -p tcp --dport 22 \
    -m state --state NEW \
    -m recent --name ssh_brute --set
sudo ip netns exec web iptables -A INPUT -p tcp --dport 22 \
    -m state --state NEW \
    -m recent --name ssh_brute --update --seconds 60 --hitcount 4 \
    -j LOG --log-prefix "SSH-BRUTE: "
sudo ip netns exec web iptables -A INPUT -p tcp --dport 22 \
    -m state --state NEW \
    -m recent --name ssh_brute --update --seconds 60 --hitcount 4 \
    -j DROP

# Разрешить SSH (прошедшие rate limit)
sudo ip netns exec web iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Разрешить HTTP
sudo ip netns exec web iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo ip netns exec web iptables -A INPUT -p icmp -j ACCEPT
sudo ip netns exec web iptables -A INPUT -j DROP
```

**Шаг 4.** Протестируй брутфорс-защиту:

```bash
for i in $(seq 1 8); do
    sudo ip netns exec app ncat -z -w 1 10.0.0.2 22 2>/dev/null
    echo "Attempt $i: exit code $?"
    sleep 0.5
done

# Посмотри логи
sudo dmesg | grep "SSH-BRUTE" | tail -5
```

**Шаг 5.** Ограничь HTTP-запросы к web (защита от простого HTTP-флуда):

```bash
# Ограничение на хосте (FORWARD): не более 50 новых TCP-соединений в секунду к web:80
sudo iptables -I FORWARD 2 -d 10.0.0.2 -p tcp --dport 80 \
    -m state --state NEW \
    -m limit --limit 50/sec --limit-burst 100 -j ACCEPT

sudo iptables -I FORWARD 3 -d 10.0.0.2 -p tcp --dport 80 \
    -m state --state NEW -j DROP
```

> **❓ Вопрос:** `--limit 3/min --limit-burst 3` - что означает burst? Если лимит 3/мин, то без burst пройдёт только 1 пакет каждые 20 секунд. Burst позволяет «накопить» токены. Как работает token bucket algorithm в контексте iptables?

---

### Задание 8: Проброс портов (DNAT) - публикация сервисов

**Цель:** сделать web-сервер (namespace web) доступным снаружи через порт хоста.

**Шаг 1.** Настрой DNAT: порт 80 хоста → порт 80 web (10.0.0.2):

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 \
    -j DNAT --to-destination 10.0.0.2:80

# Разреши forward для этого трафика (если ещё нет)
sudo iptables -I FORWARD 2 -p tcp -d 10.0.0.2 --dport 80 \
    -m state --state NEW -j ACCEPT
```

**Шаг 2.** Для доступа с самого хоста (localhost) нужно отдельное правило OUTPUT:

```bash
sudo iptables -t nat -A OUTPUT -p tcp --dport 80 \
    -j DNAT --to-destination 10.0.0.2:80
```

**Шаг 3.** Проверь:

```bash
# С хоста
curl -s localhost:80

# Посмотри NAT-таблицу
sudo iptables -t nat -L -n -v --line-numbers
```

**Шаг 4.** Добавь DNAT для app-сервера: порт 8080 хоста → порт 8080 app:

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 \
    -j DNAT --to-destination 10.0.0.3:8080

sudo iptables -t nat -A OUTPUT -p tcp --dport 8080 \
    -j DNAT --to-destination 10.0.0.3:8080

sudo iptables -I FORWARD 2 -p tcp -d 10.0.0.3 --dport 8080 \
    -m state --state NEW -j ACCEPT
```

```bash
curl -s localhost:8080
```

**Шаг 5.** Посмотри, как NAT меняет пакеты - запусти tcpdump:

```bash
# Терминал 1: слушай br0
sudo tcpdump -i br0 -n tcp port 80

# Терминал 2: сделай запрос
curl -s localhost:80
```

> **❓ Вопрос:** В tcpdump на br0 ты видишь destination 10.0.0.2:80, хотя оригинальный запрос шёл на localhost:80. В какой цепочке произошла подмена? Что увидит tcpdump на внешнем интерфейсе?

---

### Задание 9: Сохранение и восстановление правил

**Цель:** научиться делать правила постоянными (persistent) - после перезагрузки они исчезнут без сохранения.

**Шаг 1.** Сохрани текущие правила хоста:

```bash
# Сохрани в файл
sudo iptables-save > /tmp/iptables-current.rules

# Посмотри содержимое
cat /tmp/iptables-current.rules
```

Формат файла:

```
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
...
COMMIT

*nat
:PREROUTING ACCEPT [0:0]
...
COMMIT
```

**Шаг 2.** Сохрани правила namespace'ов:

```bash
sudo ip netns exec web iptables-save > /tmp/iptables-web.rules
sudo ip netns exec db iptables-save > /tmp/iptables-db.rules

cat /tmp/iptables-web.rules
```

**Шаг 3.** Симулируй «перезагрузку» - очисти всё и восстанови:

```bash
# Очисти правила хоста
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT

# Убедись, что пусто
sudo iptables -L -n

# Восстанови
sudo iptables-restore < /tmp/iptables-current.rules

# Проверь, что всё вернулось
sudo iptables -L -n -v --line-numbers
sudo iptables -t nat -L -n -v --line-numbers
```

**Шаг 4.** Для персистентности на реальном сервере:

```bash
# Debian/Ubuntu: пакет iptables-persistent
# sudo apt install iptables-persistent
# sudo netfilter-persistent save
# sudo netfilter-persistent reload

# Файлы сохраняются в:
# /etc/iptables/rules.v4
# /etc/iptables/rules.v6
```

> **❓ Вопрос:** `iptables-restore` применяет правила атомарно - все разом. Почему это лучше, чем последовательный `iptables -A ...`? Подсказка: подумай, что произойдёт, если скрипт упадёт на середине.

---

## Часть 5: Переход на nftables

---

### Задание 10: Основы nftables - замена iptables

**Цель:** понять синтаксис nftables и пересоздать конфигурацию firewall в новом формате.

nftables - это замена iptables, iptables6, arptables и ebtables. Единый синтаксис, атомарные обновления, лучшая производительность.

**Шаг 1.** Сначала очисти iptables-правила на хосте (чтобы не конфликтовали):

```bash
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
```

**Шаг 2.** Очисти nftables:

```bash
sudo nft flush ruleset
sudo nft list ruleset
```

**Шаг 3.** Создай базовую структуру - таблицу и цепочки:

```bash
# Создать таблицу (аналог "filter" в iptables, но имя произвольное)
sudo nft add table inet firewall

# Создать цепочку INPUT
sudo nft add chain inet firewall input {type filter hook input priority 0\; policy drop\;}

# Создать цепочку FORWARD
sudo nft add chain inet firewall forward {type filter hook forward priority 0\; policy drop\;}

# Создать цепочку OUTPUT
sudo nft add chain inet firewall output {type filter hook output priority 0\; policy accept\;}

# Посмотри структуру
sudo nft list ruleset
```

> **Обрати внимание:** В nftables ты сам выбираешь имена таблиц и цепочек. `inet` - семейство (IPv4 + IPv6). Приоритет и hook определяют, куда цепочка подключается в Netfilter.

**Шаг 4.** Сравни ключевые отличия синтаксиса:

```
┌─────────────────────────┬────────────────────────────────────┐
│       iptables          │           nftables                 │
├─────────────────────────┼────────────────────────────────────┤
│ -A INPUT                │ add rule inet firewall input       │
│ -p tcp --dport 80       │ tcp dport 80                       │
│ -s 10.0.0.0/24          │ ip saddr 10.0.0.0/24              │
│ -j ACCEPT               │ accept                            │
│ -j DROP                 │ drop                               │
│ -j LOG --log-prefix "X" │ log prefix "X"                    │
│ -m state --state NEW    │ ct state new                       │
│ -m limit --limit 5/sec  │ limit rate 5/second               │
│ -m multiport 80,443     │ tcp dport {80, 443}               │
│ iptables-save           │ nft list ruleset                   │
│ iptables-restore        │ nft -f file.nft                   │
└─────────────────────────┴────────────────────────────────────┘
```

**Шаг 5.** Добавь правила INPUT (аналог Задания 2):

```bash
# Loopback
sudo nft add rule inet firewall input iif lo accept

# Established/Related
sudo nft add rule inet firewall input ct state established,related accept

# ICMP с rate limit
sudo nft add rule inet firewall input ip protocol icmp icmp type echo-request limit rate 5/second accept

# SSH от namespace'ов
sudo nft add rule inet firewall input ip saddr 10.0.0.0/24 tcp dport 22 accept

# Посмотри правила
sudo nft list chain inet firewall input
```

**Шаг 6.** Добавь правила FORWARD (аналог Задания 3):

```bash
# Established/Related
sudo nft add rule inet firewall forward ct state established,related accept

# web -> app:8080
sudo nft add rule inet firewall forward ip saddr 10.0.0.2 ip daddr 10.0.0.3 tcp dport 8080 accept

# app -> db:3306
sudo nft add rule inet firewall forward ip saddr 10.0.0.3 ip daddr 10.0.0.4 tcp dport 3306 accept

# ICMP между namespace'ами
sudo nft add rule inet firewall forward ip saddr 10.0.0.0/24 ip daddr 10.0.0.0/24 ip protocol icmp accept

# Выход в интернет
EXT_IF=$(ip route show default | awk '{print $5}')
sudo nft add rule inet firewall forward iifname "br0" oifname "$EXT_IF" accept
sudo nft add rule inet firewall forward iifname "$EXT_IF" oifname "br0" ct state related,established accept

# Логирование заблокированного
sudo nft add rule inet firewall forward log prefix \"NFT-FW-DROP: \" drop
```

**Шаг 7.** Добавь NAT:

```bash
# Создать таблицу NAT
sudo nft add table inet nat

# POSTROUTING - masquerade
sudo nft add chain inet nat postrouting {type nat hook postrouting priority 100\;}
EXT_IF=$(ip route show default | awk '{print $5}')
sudo nft add rule inet nat postrouting ip saddr 10.0.0.0/24 oifname "$EXT_IF" masquerade

# PREROUTING - DNAT для web:80
sudo nft add chain inet nat prerouting {type nat hook prerouting priority -100\;}
sudo nft add rule inet nat prerouting tcp dport 80 dnat to 10.0.0.2:80

# OUTPUT - DNAT для localhost
sudo nft add chain inet nat output {type nat hook output priority -100\;}
sudo nft add rule inet nat output tcp dport 80 dnat to 10.0.0.2:80
```

**Шаг 8.** Проверь всю конфигурацию:

```bash
sudo nft list ruleset
```

**Шаг 9.** Проверь, что всё работает:

```bash
# web -> app
sudo ip netns exec web curl -s --connect-timeout 2 10.0.0.3:8080

# app -> db
sudo ip netns exec app ncat -z -v -w 2 10.0.0.4 3306

# web -> db (заблокировано)
sudo ip netns exec web ncat -z -v -w 2 10.0.0.4 3306

# DNAT
curl -s --connect-timeout 2 localhost:80

# Ping
sudo ip netns exec web ping -c 1 10.0.0.4
```

---

### Задание 11: nftables - sets и maps (продвинутые фичи)

**Цель:** использовать sets и maps - мощные конструкции nftables, которых нет в iptables.

**Шаг 1.** Создай named set для «доверенных» IP-адресов:

```bash
# Создать set
sudo nft add set inet firewall trusted_ips { type ipv4_addr \; }

# Добавить IP
sudo nft add element inet firewall trusted_ips { 10.0.0.2, 10.0.0.3 }

# Использовать в правиле
sudo nft add rule inet firewall input ip saddr @trusted_ips tcp dport 22 accept

# Посмотреть set
sudo nft list set inet firewall trusted_ips
```

**Шаг 2.** Создай set портов, которые открыты на web:

```bash
# Set портов
sudo nft add set inet firewall web_ports { type inet_service \; }
sudo nft add element inet firewall web_ports { 80, 443, 8080 }

# Правило: разрешить трафик на любой из этих портов к web
sudo nft add rule inet firewall forward ip daddr 10.0.0.2 tcp dport @web_ports accept

# Посмотри
sudo nft list set inet firewall web_ports
```

**Шаг 3.** Динамический set - автоматический бан при брутфорсе:

```bash
# Создать set для забаненных IP с автоудалением через 5 минут
sudo nft add set inet firewall ssh_banned {type ipv4_addr\; flags timeout\; timeout 5m\;}

# Создать set-счётчик подключений
sudo nft add set inet firewall ssh_meter {type ipv4_addr\; flags dynamic\;}

# Правило: если IP в бан-листе - дропай
sudo nft insert rule inet firewall input ip saddr @ssh_banned drop

# Правило: если более 4 SSH-подключений за 60 сек - в бан
sudo nft add rule inet firewall input tcp dport 22 ct state new \
    add @ssh_meter { ip saddr limit rate over 4/minute } \
    add @ssh_banned { ip saddr } drop
```

**Шаг 4.** Протестируй (из app пробуй SSH к хосту):

```bash
for i in $(seq 1 8); do
    sudo ip netns exec app ncat -z -w 1 10.0.0.1 22 2>/dev/null
    echo "Attempt $i: exit code $?"
done

# Посмотри, попал ли IP в бан
sudo nft list set inet firewall ssh_banned
```

**Шаг 5.** Maps - маршрутизация трафика по портам (verdict maps):

```bash
# Создай verdict map: порт -> действие
sudo nft add map inet firewall port_policy { type inet_service : verdict \; }
sudo nft add element inet firewall port_policy { 80 : accept, 443 : accept, 22 : drop, 3306 : drop }

# Используй в правиле
sudo nft add rule inet firewall input tcp dport vmap @port_policy
```

> **❓ Вопрос:** Sets в nftables обновляются атомарно и хранятся в ядре в виде хеш-таблиц или деревьев. Чем это лучше, чем 100 отдельных iptables-правил `-s IP1 -j DROP`, `-s IP2 -j DROP` и т.д.?

---

### Задание 12: nftables - конфигурация из файла

**Цель:** научиться хранить конфигурацию nftables в файле и применять атомарно.

**Шаг 1.** Экспортируй текущую конфигурацию:

```bash
sudo nft list ruleset > /tmp/nftables-current.conf
cat /tmp/nftables-current.conf
```

**Шаг 2.** Создай конфигурационный файл с нуля:

```bash
cat > /tmp/nftables-lab.conf << 'EOF'
#!/usr/sbin/nft -f

# Очистить всё
flush ruleset

# === ТАБЛИЦА FILTER ===
table inet firewall {

    # --- Sets ---
    set trusted_admins {
        type ipv4_addr
        elements = { 10.0.0.1 }
    }

    set internal_nets {
        type ipv4_addr
        flags interval
        elements = { 10.0.0.0/24 }
    }

    # --- INPUT ---
    chain input {
        type filter hook input priority 0; policy drop;

        # Loopback
        iif lo accept

        # Conntrack
        ct state established,related accept
        ct state invalid drop

        # ICMP rate limited
        ip protocol icmp icmp type echo-request limit rate 5/second accept

        # SSH от доверенных
        ip saddr @internal_nets tcp dport 22 accept

        # Логирование заблокированного
        limit rate 10/minute log prefix "NFT-INPUT-DROP: "
    }

    # --- FORWARD ---
    chain forward {
        type filter hook forward priority 0; policy drop;

        # Conntrack
        ct state established,related accept
        ct state invalid drop

        # web -> app:8080
        ip saddr 10.0.0.2 ip daddr 10.0.0.3 tcp dport 8080 accept

        # app -> db:3306
        ip saddr 10.0.0.3 ip daddr 10.0.0.4 tcp dport 3306 accept

        # ICMP внутри сети
        ip saddr 10.0.0.0/24 ip daddr 10.0.0.0/24 ip protocol icmp accept

        # Выход в интернет (имя интерфейса подставь своё)
        iifname "br0" oifname != "br0" accept
        ct state related,established accept

        # Логирование
        limit rate 10/minute log prefix "NFT-FWD-DROP: "
    }

    # --- OUTPUT ---
    chain output {
        type filter hook output priority 0; policy accept;
    }
}

# === ТАБЛИЦА NAT ===
table inet nat {
    chain prerouting {
        type nat hook prerouting priority -100;
        tcp dport 80 dnat to 10.0.0.2:80
        tcp dport 8080 dnat to 10.0.0.3:8080
    }

    chain postrouting {
        type nat hook postrouting priority 100;
        ip saddr 10.0.0.0/24 oifname != "br0" masquerade
    }

    chain output {
        type nat hook output priority -100;
        tcp dport 80 dnat to 10.0.0.2:80
    }
}
EOF
```

**Шаг 3.** Примени конфигурацию:

```bash
# Валидация (проверка синтаксиса без применения)
sudo nft -c -f /tmp/nftables-lab.conf
echo "Validation exit code: $?"

# Применение
sudo nft -f /tmp/nftables-lab.conf

# Проверь
sudo nft list ruleset
```

**Шаг 4.** Проверь, что всё работает:

```bash
sudo ip netns exec web curl -s --connect-timeout 2 10.0.0.3:8080
sudo ip netns exec app ncat -z -v -w 2 10.0.0.4 3306
sudo ip netns exec web ncat -z -v -w 2 10.0.0.4 3306
sudo ip netns exec web ping -c 1 10.0.0.4
curl -s --connect-timeout 2 localhost:80
```

**Шаг 5.** Для персистентности на реальном сервере:

```bash
# Файл конфигурации nftables
# /etc/nftables.conf

# Включение при загрузке
# sudo systemctl enable nftables
# sudo systemctl start nftables
```

> **❓ Вопрос:** `nft -f` применяет весь файл атомарно - либо все правила применяются, либо ни одно. Почему это критически важно для production-серверов? Что было бы, если правила применялись по одному и скрипт упал посередине?

---

## Часть 6: Практические сценарии

---

### Задание 13: Трассировка пакетов - полная отладка

**Цель:** использовать nftables trace для пошаговой отладки прохождения пакета через все цепочки.

**Шаг 1.** Включи трассировку для конкретного трафика:

```bash
# Добавь правило trace в начало prerouting
sudo nft add chain inet firewall trace_chain { type filter hook prerouting priority -200\; }
sudo nft add rule inet firewall trace_chain ip saddr 10.0.0.2 ip daddr 10.0.0.4 meta nftrace set 1
```

**Шаг 2.** Запусти мониторинг трассировки:

```bash
# Терминал 1: мониторинг
sudo nft monitor trace
```

```bash
# Терминал 2: сгенерируй трафик (web -> db - заблокирован)
sudo ip netns exec web ncat -z -w 2 10.0.0.4 3306 2>/dev/null
```

В терминале 1 ты увидишь полный путь пакета через каждую цепочку, каждое правило, с указанием verdict (accept/drop/continue).

**Шаг 3.** Попробуй разрешённый трафик:

```bash
# Удали старое правило trace и добавь новое для app -> db
sudo nft flush chain inet firewall trace_chain
sudo nft add rule inet firewall trace_chain ip saddr 10.0.0.3 ip daddr 10.0.0.4 meta nftrace set 1
```

```bash
# Терминал 1: мониторинг
sudo nft monitor trace
```

```bash
# Терминал 2:
sudo ip netns exec app ncat -z -w 2 10.0.0.4 3306
```

Сравни: для заблокированного трафика путь заканчивается на drop, для разрешённого - accept.

**Шаг 4.** Очисти trace (чтобы не засорял):

```bash
sudo nft delete chain inet firewall trace_chain
```

> **❓ Вопрос:** В iptables для отладки приходится добавлять LOG-правила перед каждой цепочкой. В nftables trace показывает весь путь автоматически. Для каких реальных ситуаций это критично? Подсказка: «трафик дропается, но не понимаю где».

---

### Задание 14: Итоговый сценарий - полная конфигурация production firewall

**Цель:** собрать всё вместе в финальную конфигурацию, имитирующую реальный production-стек.

Политика безопасности:

| Источник | Назначение | Порт | Действие |
|----------|-----------|------|----------|
| Интернет | web | 80, 443 | ACCEPT |
| web | app | 8080 | ACCEPT |
| app | db | 3306 | ACCEPT |
| Хост (admin) | web, app, db | 22 | ACCEPT |
| Все namespace'ы | Интернет | any | ACCEPT (NAT) |
| Все namespace'ы | Друг к другу | ICMP | ACCEPT |
| Всё остальное | - | - | DROP + LOG |

**Шаг 1.** Создай финальный конфигурационный файл:

```bash
cat > /tmp/nftables-production.conf << 'NFTEOF'
#!/usr/sbin/nft -f

flush ruleset

# =============================================
#  Production Firewall - 3-tier Architecture
# =============================================

table inet firewall {

    # --- Named Sets ---

    set admin_ips {
        type ipv4_addr
        comment "Адреса администраторов"
        elements = { 10.0.0.1 }
    }

    set web_ports {
        type inet_service
        comment "Публичные порты web-сервера"
        elements = { 80, 443 }
    }

    set internal_net {
        type ipv4_addr
        flags interval
        elements = { 10.0.0.0/24 }
    }

    # Динамический set для anti-bruteforce
    set ssh_banned {
        type ipv4_addr
        flags timeout
        timeout 10m
        comment "Автобан SSH-брутфорс"
    }

    # --- INPUT: защита хоста-роутера ---

    chain input {
        type filter hook input priority 0; policy drop;

        # Fast path
        iif lo accept
        ct state established,related accept
        ct state invalid counter drop

        # Anti-bruteforce SSH
        ip saddr @ssh_banned counter drop

        # ICMP (rate limited)
        ip protocol icmp icmp type echo-request limit rate 10/second counter accept
        ip protocol icmp icmp type { destination-unreachable, time-exceeded } accept

        # SSH от внутренней сети
        ip saddr @internal_net tcp dport 22 counter accept

        # Логирование заблокированного
        limit rate 15/minute counter log prefix "INPUT-DROP: "
        counter comment "default drop"
    }

    # --- FORWARD: межсегментный firewall ---

    chain forward {
        type filter hook forward priority 0; policy drop;

        # Fast path
        ct state established,related counter accept
        ct state invalid counter drop

        # === Tier 1: Internet -> web ===
        ip daddr 10.0.0.2 tcp dport @web_ports ct state new counter accept

        # === Tier 2: web -> app ===
        ip saddr 10.0.0.2 ip daddr 10.0.0.3 tcp dport 8080 ct state new counter accept

        # === Tier 3: app -> db ===
        ip saddr 10.0.0.3 ip daddr 10.0.0.4 tcp dport 3306 ct state new counter accept

        # === Admin: host -> all servers SSH ===
        ip saddr @admin_ips ip daddr @internal_net tcp dport 22 ct state new counter accept

        # === Диагностика: ICMP внутри ===
        ip saddr @internal_net ip daddr @internal_net ip protocol icmp counter accept

        # === Интернет: namespace -> наружу ===
        iifname "br0" oifname != "br0" counter accept

        # Логирование
        limit rate 15/minute counter log prefix "FORWARD-DROP: "
        counter comment "default drop"
    }

    # --- OUTPUT ---

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

# === NAT ===

table inet nat {
    chain prerouting {
        type nat hook prerouting priority -100;

        # Публикация web-сервера
        tcp dport 80 dnat to 10.0.0.2:80
        tcp dport 443 dnat to 10.0.0.2:443
        tcp dport 8080 dnat to 10.0.0.3:8080
    }

    chain postrouting {
        type nat hook postrouting priority 100;

        # Masquerade для выхода в интернет
        ip saddr 10.0.0.0/24 oifname != "br0" masquerade
    }

    chain output {
        type nat hook output priority -100;
        tcp dport 80 dnat to 10.0.0.2:80
    }
}
NFTEOF
```

**Шаг 2.** Примени:

```bash
sudo nft -c -f /tmp/nftables-production.conf && echo "Syntax OK"
sudo nft -f /tmp/nftables-production.conf
```

**Шаг 3.** Полная проверка:

```bash
echo "=== Test 1: web -> app:8080 (ALLOW) ==="
sudo ip netns exec web curl -s --connect-timeout 2 10.0.0.3:8080

echo ""
echo "=== Test 2: app -> db:3306 (ALLOW) ==="
sudo ip netns exec app ncat -z -v -w 2 10.0.0.4 3306

echo ""
echo "=== Test 3: web -> db:3306 (DENY) ==="
sudo ip netns exec web ncat -z -v -w 2 10.0.0.4 3306

echo ""
echo "=== Test 4: web -> app:22 (DENY) ==="
sudo ip netns exec web ncat -z -v -w 2 10.0.0.3 22

echo ""
echo "=== Test 5: app -> web:80 (DENY - обратное направление) ==="
sudo ip netns exec app ncat -z -v -w 2 10.0.0.2 80

echo ""
echo "=== Test 6: DNAT - localhost:80 -> web (ALLOW) ==="
curl -s --connect-timeout 2 localhost:80

echo ""
echo "=== Test 7: Ping web -> db (ALLOW) ==="
sudo ip netns exec web ping -c 1 -W 2 10.0.0.4

echo ""
echo "=== Test 8: Internet from web (ALLOW) ==="
sudo ip netns exec web ping -c 1 -W 2 8.8.8.8
```

**Шаг 4.** Посмотри счётчики - какие правила срабатывают:

```bash
sudo nft list ruleset | grep -E "counter packets [1-9]"
```

---

### Задание 15: Очистка

```bash
# Удали nftables
sudo nft flush ruleset

# Убей процессы в namespace'ах
for NS in web app db; do
    sudo ip netns pids $NS 2>/dev/null | xargs -r sudo kill 2>/dev/null
done

# Удали namespace'ы
for NS in web app db; do
    sudo ip netns del $NS 2>/dev/null
done

# Удали bridge
sudo ip link del br0 2>/dev/null

# Выключи forwarding
sudo sysctl -w net.ipv4.ip_forward=0

# Очисти iptables (на случай если остались)
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT

# Проверь
ip netns list
ip link show type bridge
sudo nft list ruleset
sudo iptables -L -n
```

---

## Чеклист выполнения

- [ ] Инфраструктура: 3 namespace'а с bridge, сервисы запущены
- [ ] Структура iptables: таблицы, цепочки, путь пакета понятен
- [ ] INPUT firewall: default deny, SSH, ICMP с rate limit
- [ ] FORWARD firewall: трёхуровневая модель (web→app→db)
- [ ] Firewall внутри namespace'ов (defense in depth)
- [ ] Conntrack: состояния соединений, мониторинг
- [ ] Логирование: LOG target, prefix, rate limit логов
- [ ] Rate limiting: limit, recent, защита от брутфорса
- [ ] DNAT: проброс портов хоста в namespace'ы
- [ ] iptables-save / iptables-restore: сохранение и восстановление
- [ ] nftables: таблицы, цепочки, правила - базовый синтаксис
- [ ] nftables sets и maps: named sets, динамические sets, verdict maps
- [ ] nftables из файла: конфигурация, валидация, атомарное применение
- [ ] nftables trace: пошаговая отладка прохождения пакета
- [ ] Production-конфигурация: полный firewall для 3-tier архитектуры
- [ ] Очистка: все ресурсы удалены

---

## Ответы на вопросы (для самопроверки)

---

**Задание 1 - почему в filter нет PREROUTING**

> Каждая таблица подключается к определённым hook-точкам Netfilter. Таблица `filter` подключена к `INPUT`, `FORWARD`, `OUTPUT` - точкам, где принимается решение о фильтрации. `PREROUTING` и `POSTROUTING` - это точки для модификации пакетов (NAT, mangle), они срабатывают до/после решения о маршрутизации. Транзитный пакет проходит: `PREROUTING (nat)` → routing decision → `FORWARD (filter)` → `POSTROUTING (nat)`.

---

**Задание 1 - порядок правил**

> Если `DROP all` стоит выше `ACCEPT ssh`, SSH-пакет будет отброшен - iptables применяет первое совпавшее правило и прекращает обработку цепочки. Порядок критичен: более специфичные правила должны стоять выше общих.

---

**Задание 2 - DROP vs REJECT**

> Для внешнего firewall лучше DROP: атакующий не получает никакой информации (порт выглядит как «filtered» или даже «хост не существует»). Для внутренней сети лучше REJECT: легитимные клиенты получают мгновенный отказ вместо долгого таймаута, что ускоряет диагностику проблем.

---

**Задание 3 - ICMP vs TCP фильтрация**

> Правила фильтрации работают по совокупности критериев: протокол + порт + адреса. Правило `ICMP ACCEPT` разрешает только ICMP-пакеты (protocol 1). TCP-пакеты к MySQL (protocol 6, port 3306) проверяются другими правилами и не совпадают с ICMP-правилом. Фильтрация работает на L3-L4 (IP + TCP/UDP/ICMP).

---

**Задание 4 - defense in depth**

> Defense in depth - многоуровневая защита. FORWARD-правила на роутере - первая линия. INPUT-правила внутри namespace - вторая. Если атакующий получит доступ к app и попробует подключиться к db на нестандартном порту (например, 22), FORWARD может пропустить (если правило широкое), но INPUT в db заблокирует. Два уровня фильтрации снижают риск ошибки в конфигурации.

---

**Задание 5 - RELATED**

> RELATED - пакет, который связан с существующим соединением, но не является его частью. Примеры: ICMP «destination unreachable» в ответ на TCP-пакет (связан с TCP-соединением, но это ICMP-пакет); FTP data connection (порт 20), связанная с control connection (порт 21); ICMP «fragmentation needed» при Path MTU Discovery.

---

**Задание 5 - stateless опасность**

> Правило `--sport 80 -j ACCEPT` пропускает ЛЮБОЙ пакет с source port 80, даже если никакого HTTP-соединения не было. Атакующий может отправить пакет с `source port 80` и обойти firewall. Conntrack решает эту проблему: пакет принимается только если он принадлежит соединению, которое было инициировано изнутри.

---

**Задание 6 - LOG не terminating**

> LOG записывает информацию о пакете и возвращает управление следующему правилу. Это позволяет одновременно и логировать, и принимать решение (ACCEPT/DROP). Если бы LOG был terminating, нельзя было бы логировать и блокировать одним набором правил - пришлось бы дублировать условия.

---

**Задание 7 - token bucket**

> Token bucket: «ведро» наполняется токенами с заданной скоростью (limit). Burst - максимальная ёмкость ведра. Каждый пакет забирает 1 токен. Если ведро пусто - пакет дропается. `--limit 3/min --limit-burst 3`: ведро вмещает 3 токена, наполняется со скоростью 1 токен каждые 20 секунд. В начале 3 пакета пройдут мгновенно (burst), затем - не чаще 1 каждые 20 секунд.

---

**Задание 8 - DNAT и цепочки**

> Подмена destination произошла в `PREROUTING` (для внешних пакетов) или `OUTPUT` (для локальных). На br0 уже видно 10.0.0.2:80, потому что DNAT сработал до routing decision. На внешнем интерфейсе tcpdump покажет оригинальный destination (IP хоста, порт 80), потому что DNAT ещё не произошёл - пакет только пришёл.

---

**Задание 9 - атомарное применение**

> `iptables-restore` загружает все правила одной операцией ядра. При последовательном `iptables -A` между командами есть окно, когда firewall в неконсистентном состоянии. Если скрипт упадёт после `iptables -P INPUT DROP`, но до добавления `ACCEPT` правил - хост станет недоступен. Атомарное применение исключает промежуточные состояния.

---

**Задание 11 - sets vs множество правил**

> 100 правил `iptables -s IP -j DROP` - линейный поиск O(n) по каждому пакету. nftables set - хеш-таблица O(1) или rb-tree O(log n). При 10 000 заблокированных IP разница колоссальная. Кроме того, set обновляется атомарно: добавление/удаление IP не требует перезагрузки всех правил.

---

**Задание 12 - атомарность nft -f**

> Если правила применяются по одному и скрипт упадёт на середине, firewall окажется в непредсказуемом состоянии: часть правил применена, часть - нет. Это может привести к: (1) полной блокировке трафика (DROP policy без ACCEPT-правил), (2) полному открытию (ACCEPT-правила без DROP). `nft -f` гарантирует: либо всё применилось корректно, либо ничего не изменилось.

---

**Задание 13 - nftables trace**

> Trace критичен, когда трафик дропается, но непонятно каким правилом. В сложных конфигурациях с десятками цепочек и правил ручной анализ невозможен. Trace показывает точную цепочку и номер правила, которое приняло решение. Без trace приходится добавлять LOG перед каждым правилом, что засоряет конфигурацию и логи.
