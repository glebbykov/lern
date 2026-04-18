# Linux Bridge — Практическая лабораторная работа

**Network namespaces, veth-пары, bridge — строим виртуальную сеть руками**

---

## Обзор лабораторной

В этой лабораторной ты руками соберёшь то, что Docker и Kubernetes делают автоматически: создашь изолированные сетевые пространства (network namespaces), соединишь их виртуальными кабелями (veth-пары) и свяжешь через виртуальный свитч (Linux bridge). Всё на обычной VM, без Docker, без облачных сервисов.

## Что ты построишь

```
  Namespace: red        Namespace: blue       Namespace: green
┌──────────────┐     ┌──────────────┐      ┌──────────────┐
│     eth0     │     │     eth0     │      │     eth0     │
│  10.0.0.2/24 │     │  10.0.0.3/24 │      │  10.0.0.4/24 │
└──────┬───────┘     └──────┬───────┘      └──────┬───────┘
       │  veth-red          │ veth-blue           │ veth-green
       │                    │                     │
┌──────┴────────────────────┴─────────────────────┴──────┐
│                    br0 (bridge)                        │
│                    10.0.0.1/24                         │
└───────────────────────┬────────────────────────────────┘
                        │
                  Host (iptables NAT)
                        │
                     Internet
```

## Что нужно

- Любая Linux VM (Ubuntu 20.04+, Debian 11+, CentOS 8+). Подойдёт даже локальная виртуалка в VirtualBox.
- Root-доступ (`sudo`).
- Никаких дополнительных пакетов — всё через `iproute2`, который есть из коробки.

## Ключевые концепции

| Концепция | Описание |
|-----------|----------|
| **Network Namespace** | Изолированный сетевой стек: свои интерфейсы, маршруты, iptables |
| **veth pair** | Виртуальный Ethernet-кабель: два конца, пакет входит в один — выходит из другого |
| **Bridge** | Виртуальный L2-свитч в ядре: соединяет интерфейсы в один broadcast-домен |

---

## Часть 1: Основы

---

### Задание 1: Создание Network Namespaces

**Цель:** понять, что такое network namespace и убедиться, что он полностью изолирован от хоста.

**Шаг 1.** Создай два namespace:

```bash
sudo ip netns add red
sudo ip netns add blue

# Проверь
ip netns list
```

**Шаг 2.** Загляни внутрь namespace `red`:

```bash
# Какие интерфейсы есть?
sudo ip netns exec red ip link show

# Какие маршруты?
sudo ip netns exec red ip route show

# Что с loopback?
sudo ip netns exec red ping -c 1 127.0.0.1
```

> **❓ Вопрос:** Ping на 127.0.0.1 не работает. Почему?
> *Подсказка: посмотри состояние lo интерфейса.*

**Шаг 3.** Подними loopback:

```bash
sudo ip netns exec red ip link set lo up
sudo ip netns exec red ping -c 1 127.0.0.1
```

**Шаг 4.** Убедись в изоляции — namespace не видит интерфейсы хоста:

```bash
# На хосте (ты увидишь все свои интерфейсы: lo, eth0/enp3s0, docker0 и т.д.)
ip -br link show

# В изолированном namespace (ты увидишь ТОЛЬКО loopback интерфейс lo)
sudo ip netns exec red ip -br link show
```

> **❓ Вопрос:** Namespace видит только `lo`. Это значит, что каждый namespace имеет полностью свой сетевой стек. Как думаешь, у каждого namespace свои iptables-правила тоже?

Проверь:

```bash
sudo ip netns exec red iptables -L -n
sudo iptables -L -n
```

---

### Задание 2: veth-пары — виртуальные кабели

**Цель:** соединить два namespace напрямую veth-парой и установить связь.

**Шаг 1.** Создай veth-пару:

```bash
sudo ip link add veth-red type veth peer name veth-blue

# Посмотри — оба конца на хосте
ip link show type veth
```

**Шаг 2.** Раскидай концы по namespace:

```bash
# Один конец в red
sudo ip link set veth-red netns red

# Другой в blue
sudo ip link set veth-blue netns blue

# Проверь — на хосте veth пропали
ip link show type veth

# Они теперь внутри namespace
sudo ip netns exec red ip link show
sudo ip netns exec blue ip link show
```

> **❓ Вопрос:** После `ip link set ... netns red`, интерфейс исчез с хоста. Он физически переместился? Что произошло на уровне ядра?

**Шаг 3.** Назначь IP-адреса и подними интерфейсы:

```bash
# В red
sudo ip netns exec red ip addr add 10.0.0.2/24 dev veth-red
sudo ip netns exec red ip link set veth-red up

# В blue
sudo ip netns exec blue ip addr add 10.0.0.3/24 dev veth-blue
sudo ip netns exec blue ip link set veth-blue up
```

**Шаг 4.** Проверь связь:

```bash
sudo ip netns exec red ping -c 3 10.0.0.3
sudo ip netns exec blue ping -c 3 10.0.0.2
```

**Шаг 5.** Посмотри ARP-таблицу:

```bash
sudo ip netns exec red ip neigh show
```

> **❓ Вопрос:** Ты видишь MAC-адрес blue в ARP-таблице red. Как пакет нашёл этот MAC, если нет свитча? Через какой механизм прошёл ARP-запрос?

---

### Задание 3: Создание bridge

**Цель:** пересобрать сеть с bridge — виртуальным свитчем, к которому подключены namespace.

> ⚠️ **Важно:** Сначала удалим прямое veth-соединение из Задания 2. В новой схеме каждый namespace подключён к bridge, а не друг к другу.

**Шаг 1.** Удали старые namespace и начни с чистого листа:

```bash
sudo ip netns del red
sudo ip netns del blue
```

**Шаг 2.** Создай bridge:

```bash
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip addr add 10.0.0.1/24 dev br0

# Проверь
ip addr show br0
```

> **❓ Вопрос:** Мы дали bridge IP-адрес 10.0.0.1. Зачем? Bridge работает на L2, ему не нужен IP для пересылки фреймов. Для чего тогда этот адрес?

**Шаг 3.** Создай три namespace и подключи каждый к bridge:

```bash
for NS in red blue green; do
    # Создать namespace
    sudo ip netns add $NS
    sudo ip netns exec $NS ip link set lo up

    # Создать veth-пару
    sudo ip link add veth-$NS type veth peer name eth0-$NS

    # Один конец — в bridge (на хосте)
    sudo ip link set veth-$NS master br0
    sudo ip link set veth-$NS up

    # Другой конец — в namespace
    sudo ip link set eth0-$NS netns $NS
done
```

**Шаг 4.** Назначь IP и подними интерфейсы внутри namespace:

```bash
sudo ip netns exec red ip addr add 10.0.0.2/24 dev eth0-red
sudo ip netns exec red ip link set eth0-red up

sudo ip netns exec blue ip addr add 10.0.0.3/24 dev eth0-blue
sudo ip netns exec blue ip link set eth0-blue up

sudo ip netns exec green ip addr add 10.0.0.4/24 dev eth0-green
sudo ip netns exec green ip link set eth0-green up
```

**Шаг 5.** Проверь, что все видят всех:

```bash
sudo ip netns exec red ping -c 2 10.0.0.3    # red -> blue
sudo ip netns exec red ping -c 2 10.0.0.4    # red -> green
sudo ip netns exec blue ping -c 2 10.0.0.4   # blue -> green
sudo ip netns exec green ping -c 2 10.0.0.1  # green -> bridge (host)
```

---

### Задание 4: Исследование L2 — MAC-таблица, ARP, tcpdump

**Цель:** увидеть, как bridge работает на канальном уровне — MAC-таблица, ARP, broadcast.

**Шаг 1.** Посмотри MAC-таблицу bridge (FDB — Forwarding DataBase):

```bash
bridge fdb show br br0
```

Ты увидишь MAC-адреса и к какому порту (veth) они привязаны. Это аналог CAM-таблицы физического свитча.

**Шаг 2.** Посмотри, какие интерфейсы подключены к bridge:

```bash
bridge link show
```

**Шаг 3.** Запусти tcpdump на bridge и наблюдай трафик:

```bash
# Терминал 1: слушай bridge
sudo tcpdump -i br0 -n -e
```

```bash
# Терминал 2: пингуй из red в blue
sudo ip netns exec red ping -c 3 10.0.0.3
```

> **❓ Вопрос:** В tcpdump ты видишь ARP-запросы и ICMP. Обрати внимание на флаг `-e` — он показывает MAC-адреса. Кто отправляет ARP who-has? Кто отвечает? Через какой интерфейс ответ приходит?

**Шаг 4.** Проверь ARP из каждого namespace:

```bash
sudo ip netns exec red ip neigh show
sudo ip netns exec blue ip neigh show
sudo ip netns exec green ip neigh show
```

**Шаг 5.** Эксперимент с broadcast — слушай на green, пока red пингует blue:

```bash
# Терминал 1: tcpdump в green
sudo ip netns exec green tcpdump -i eth0-green -n -e
```

```bash
# Терминал 2: из red пингуй blue
sudo ip netns exec red ping -c 3 10.0.0.3
```

> **❓ Вопрос:** Видит ли green ARP-запросы от red? А сами ICMP-пакеты? Почему одни видит, а другие нет?
> *Подсказка: ARP — broadcast, ICMP — unicast.*

---

## Часть 2: Маршрутизация и NAT

---

### Задание 5: Выход в интернет через bridge + NAT

**Цель:** дать namespace доступ в интернет. Это то, что Docker делает автоматически при `docker run`.

**Шаг 1.** Сначала проверь, что интернета нет:

```bash
sudo ip netns exec red ping -c 2 -W 2 8.8.8.8
# Не работает — нет default route
```

**Шаг 2.** Добавь default route в каждый namespace:

```bash
sudo ip netns exec red ip route add default via 10.0.0.1
sudo ip netns exec blue ip route add default via 10.0.0.1
sudo ip netns exec green ip route add default via 10.0.0.1

# Проверь
sudo ip netns exec red ip route show
```

Теперь пакеты из namespace уходят на 10.0.0.1 (bridge на хосте). Но хост должен их переслать дальше.

**Шаг 3.** Включи IP forwarding:

```bash
sudo sysctl -w net.ipv4.ip_forward=1

# Проверь
cat /proc/sys/net/ipv4/ip_forward
```

> **❓ Вопрос:** Без `ip_forward=1` ядро Linux дропает пакеты, которые не адресованы ему. Зачем такое поведение по умолчанию?

**Шаг 4.** Настрой NAT (masquerade):

```bash
# Узнай имя внешнего интерфейса хоста
ip route show default
# Обычно ens4, eth0, enp0s3 и т.д.

# Подставь своё имя интерфейса вместо ens4
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 \
    -o ens4 -j MASQUERADE

# Разреши forward-трафик
sudo iptables -A FORWARD -i br0 -o ens4 -j ACCEPT
sudo iptables -A FORWARD -i ens4 -o br0 \
    -m state --state RELATED,ESTABLISHED -j ACCEPT
```

> **Что происходит:**
> - `MASQUERADE` — пакет из 10.0.0.2 уходит наружу с source IP хоста.
> - `FORWARD ACCEPT` — разрешаем хосту пересылать пакеты из br0 наружу.
> - `RELATED,ESTABLISHED` — ответные пакеты пропускаем обратно в br0.
> - Это ровно то, что делает Docker с сетью `docker0`!

**Шаг 5.** Проверь доступ в интернет:

```bash
sudo ip netns exec red ping -c 3 8.8.8.8
sudo ip netns exec blue ping -c 3 1.1.1.1
```

**Шаг 6.** Проверь DNS (нужен резолвер):

```bash
# Создай resolv.conf для namespace
sudo mkdir -p /etc/netns/red
echo 'nameserver 8.8.8.8' | sudo tee /etc/netns/red/resolv.conf

# Теперь DNS работает
sudo ip netns exec red ping -c 2 example.com
```

> **❓ Вопрос:** Мы используем MASQUERADE, а не SNAT. Вспомни лекцию — почему здесь masquerade уместен? В каком случае лучше было бы использовать SNAT?

---

### Задание 6: Проброс портов (DNAT) — входящий трафик

**Цель:** сделать сервис внутри namespace доступным снаружи. Это аналог `docker run -p 8080:80`.

**Шаг 1.** Запусти простой HTTP-сервер в namespace red:

```bash
# Установи ncat если нет
sudo apt-get install -y ncat 2>/dev/null || sudo yum install -y nmap-ncat

# Запусти сервер в red на порту 80
sudo ip netns exec red sh -c \
    'echo "Hello from namespace red!" | ncat -l -p 80 -k &'
```

**Шаг 2.** Проверь, что сервер работает изнутри:

```bash
sudo ip netns exec blue curl -s 10.0.0.2:80
# Должен вернуть: Hello from namespace red!
```

**Шаг 3.** Настрой DNAT для проброса порта 8080 хоста → порт 80 в red:

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 \
    -j DNAT --to-destination 10.0.0.2:80

sudo iptables -A FORWARD -p tcp -d 10.0.0.2 --dport 80 -j ACCEPT
```

**Шаг 4.** Проверь с хоста:

```bash
curl -s localhost:8080
```

**Шаг 5.** Посмотри, что происходит в iptables:

```bash
sudo iptables -t nat -L -n -v
sudo iptables -L FORWARD -n -v
```

> **❓ Вопрос:** Ты настроил DNAT в PREROUTING. Почему именно PREROUTING, а не OUTPUT или POSTROUTING? Нарисуй путь пакета через цепочки iptables.

> **Сравни с Docker:**
> `docker run -p 8080:80 nginx` делает ровно то же самое:
> 1. Создаёт veth-пару (контейнер ↔ docker0)
> 2. DNAT: `PREROUTING --dport 8080 → container_ip:80`
> 3. MASQUERADE: `POSTROUTING` для исходящего трафика контейнера
>
> Ты только что повторил это руками!

---

### Задание 7: VLAN на bridge — сегментация сети

**Цель:** разделить namespace на разные VLAN и убедиться, что они изолированы друг от друга на L2.

**Шаг 1.** Включи VLAN filtering на bridge:

```bash
sudo ip link set br0 type bridge vlan_filtering 1
```

**Шаг 2.** Назначь VLAN: red и blue в VLAN 10, green в VLAN 20:

```bash
# red -> VLAN 10
sudo bridge vlan add vid 10 dev veth-red pvid untagged
sudo bridge vlan del vid 1 dev veth-red

# blue -> VLAN 10
sudo bridge vlan add vid 10 dev veth-blue pvid untagged
sudo bridge vlan del vid 1 dev veth-blue

# green -> VLAN 20
sudo bridge vlan add vid 20 dev veth-green pvid untagged
sudo bridge vlan del vid 1 dev veth-green

# Проверь
bridge vlan show
```

> **PVID и untagged:**
> - `pvid` (Port VLAN ID) — входящие нетегированные фреймы попадают в этот VLAN.
> - `untagged` — исходящие фреймы из этого VLAN отправляются без тега.
> - Это аналог access-порта на физическом свитче.

**Шаг 3.** Проверь изоляцию:

```bash
# Сбрось ARP-кэш
sudo ip netns exec red ip neigh flush all
sudo ip netns exec green ip neigh flush all

# red -> blue (оба VLAN 10) — должен работать
sudo ip netns exec red ping -c 2 -W 2 10.0.0.3

# red -> green (разные VLAN) — НЕ должен работать
sudo ip netns exec red ping -c 2 -W 2 10.0.0.4
```

> **❓ Вопрос:** red не может пинговать green, хотя они в одной IP-подсети 10.0.0.0/24. Почему? На каком уровне OSI произошла блокировка? Что нужно добавить, чтобы VLAN 10 и VLAN 20 могли общаться?

---

### Задание 8: Очистка

Удали все созданные ресурсы:

```bash
# Namespace (удаление автоматически удаляет veth-пары)
sudo ip netns del red
sudo ip netns del blue
sudo ip netns del green

# Bridge
sudo ip link del br0

# iptables
sudo iptables -t nat -F
sudo iptables -F FORWARD

# ip_forward
sudo sysctl -w net.ipv4.ip_forward=0

# DNS config
sudo rm -rf /etc/netns/red

# Проверь, что всё чисто
ip netns list
ip link show type bridge
sudo iptables -t nat -L -n
```

> **❓ Вопрос:** Почему удаление namespace автоматически удаляет veth-пары? Что происходит с тем концом, который был подключён к bridge?

---

## Чеклист выполнения

- [ ] Namespace создан, loopback поднят, изоляция проверена
- [ ] veth-пара создана, namespace соединены напрямую, ping работает
- [ ] Bridge создан, три namespace подключены, все пингуют всех
- [ ] MAC-таблица (FDB) просмотрена, ARP изучен, broadcast vs unicast понятен
- [ ] IP forwarding включён, masquerade настроен, интернет из namespace работает
- [ ] DNAT настроен, порт 8080 хоста проброшен в namespace
- [ ] VLAN filtering включён, изоляция между VLAN проверена
- [ ] Все ресурсы удалены

---

## Ответы на вопросы (для самопроверки)

<details>
<summary><strong>Задание 1 — loopback не работает</strong></summary>

В новом namespace интерфейс `lo` существует, но находится в состоянии DOWN. Ядро не обрабатывает пакеты на выключенном интерфейсе. Нужно явно поднять: `ip link set lo up`.
</details>

<details>
<summary><strong>Задание 1 — свои iptables</strong></summary>

Да, каждый network namespace имеет полностью изолированный сетевой стек: свои интерфейсы, маршруты, iptables, conntrack, сокеты. Это основа контейнерной изоляции.
</details>

<details>
<summary><strong>Задание 2 — перемещение veth</strong></summary>

Интерфейс не копируется, а перемещается: ядро меняет его принадлежность от `init_net` к целевому namespace. В исходном namespace он перестаёт существовать. Это O(1) операция — меняется только указатель на `net namespace` в структуре `net_device`.
</details>

<details>
<summary><strong>Задание 2 — ARP без свитча</strong></summary>

veth-пара — это point-to-point соединение. ARP broadcast отправляется в один конец veth и выходит из другого. Нет нужды в свитче — это прямой кабель между двумя точками.
</details>

<details>
<summary><strong>Задание 3 — IP на bridge</strong></summary>

IP нужен для двух целей: (1) чтобы хост мог общаться с namespace напрямую (хост становится участником сети 10.0.0.0/24), (2) чтобы namespace могли использовать bridge как default gateway для выхода наружу через маршрутизацию хоста.
</details>

<details>
<summary><strong>Задание 4 — broadcast vs unicast</strong></summary>

Green видит ARP-запросы от red (broadcast — рассылается на все порты bridge), но не видит ICMP-пакеты (unicast — bridge знает MAC blue и отправляет фрейм только на порт veth-blue). Это именно то, что отличает bridge от hub.
</details>

<details>
<summary><strong>Задание 5 — ip_forward</strong></summary>

По умолчанию отключён из соображений безопасности. Обычная рабочая станция не должна маршрутизировать чужой трафик — это роль маршрутизатора. Включение делает хост маршрутизатором.
</details>

<details>
<summary><strong>Задание 5 — MASQUERADE vs SNAT</strong></summary>

Masquerade подходит, потому что IP хоста может быть динамическим (DHCP от облака). Если IP статический и известен — SNAT эффективнее (не нужен lookup IP на каждый пакет).
</details>

<details>
<summary><strong>Задание 6 — PREROUTING</strong></summary>

DNAT должен произойти ДО решения о маршрутизации (routing decision). Пакет приходит на хост с `dst_port 8080`, PREROUTING меняет destination на `10.0.0.2:80`, после чего ядро видит, что пакет не для хоста, и отправляет его через FORWARD в bridge. В OUTPUT DNAT работает только для локально сгенерированных пакетов.
</details>

<details>
<summary><strong>Задание 7 — VLAN изоляция</strong></summary>

Блокировка на L2: bridge не пересылает фреймы между разными VLAN. IP-подсеть одна, но L2-домены разные. Для связи между VLAN нужен маршрутизатор (inter-VLAN routing) — отдельный интерфейс или sub-interface в каждом VLAN, который маршрутизирует пакеты между ними на L3.
</details>

<details>
<summary><strong>Задание 8 — удаление veth</strong></summary>

veth — это пара. Удаление одного конца (вместе с namespace) автоматически уничтожает второй конец. Bridge обнаруживает, что порт исчез, и удаляет его из своей конфигурации. Связанные FDB-записи тоже очищаются.
</details>
