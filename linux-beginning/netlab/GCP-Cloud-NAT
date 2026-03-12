# GCP Cloud NAT — Практическая лабораторная работа

**Настройка NAT Gateway для приватных VM в Google Cloud**

## Обзор лабораторной

В этой лабораторной ты построишь типовую облачную архитектуру: приватные VM без публичных IP-адресов, которые выходят в интернет через Cloud NAT. Это стандартный паттерн безопасности в продакшн-инфраструктуре.

**Что ты сделаешь:** создашь VPC с приватной подсетью, развернёшь VM без внешнего IP, убедишься, что без NAT доступа в интернет нет, настроишь Cloud Router и Cloud NAT, проверишь исходящий доступ, исследуешь поведение NAT: порты, IP, логи.

**Что нужно:** GCP-аккаунт с активным проектом и включённым биллингом, доступ к Cloud Shell или локальный gcloud CLI, базовое понимание TCP/IP и сетей.

> ⚠️ **Стоимость:** Cloud NAT тарифицируется за время работы и объём трафика. Не забудь удалить все ресурсы после лабораторной (Задание 7).

---

## Задание 0: Настройка переменных

Задай переменные, чтобы использовать их во всех командах:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export REGION=us-central1
export ZONE=us-central1-a
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
```

Включи необходимые API:

```bash
gcloud services enable compute.googleapis.com
```

---

## Задание 1: Создание VPC и приватной подсети

**Цель:** создать изолированную сеть, в которой VM не будут иметь прямого выхода в интернет.

**Шаг 1.** Создай VPC с отключённым автоматическим созданием подсетей:

```bash
gcloud compute networks create nat-lab-vpc \
    --subnet-mode=custom \
    --bgp-routing-mode=regional
```

**Шаг 2.** Создай подсеть с приватным диапазоном:

```bash
gcloud compute networks subnets create nat-lab-subnet \
    --network=nat-lab-vpc \
    --region=$REGION \
    --range=10.0.1.0/24
```

**Шаг 3.** Создай firewall-правило для SSH (через IAP — Identity-Aware Proxy):

```bash
gcloud compute firewall-rules create nat-lab-allow-iap-ssh \
    --network=nat-lab-vpc \
    --allow=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --description="Allow SSH via IAP"
```

> **Почему IAP?** Диапазон 35.235.240.0/20 — это адреса Google IAP. IAP позволяет подключаться по SSH к VM без публичного IP. Трафик идёт через Google-инфраструктуру, а не через интернет.

**❓ Вопрос:** Почему мы выбрали `subnet-mode=custom`, а не `auto`? Что произойдёт с маршрутами в этой VPC?

---

## Задание 2: Создание приватной VM

**Цель:** развернуть VM без внешнего IP и убедиться, что она не имеет доступа в интернет.

**Шаг 1.** Создай VM без внешнего IP:

```bash
gcloud compute instances create nat-lab-vm \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --subnet=nat-lab-subnet \
    --no-address \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
apt-get update -y
apt-get install -y tcpdump curl dnsutils'
```

**Шаг 2.** Подключись через IAP:

```bash
gcloud compute ssh nat-lab-vm --zone=$ZONE --tunnel-through-iap
```

**Шаг 3.** Проверь, что внешнего IP нет:

```bash
# На VM
ip addr show ens4
curl -s --connect-timeout 5 ifconfig.me && echo || echo "No internet"
```

**Шаг 4.** Попробуй что-нибудь скачать:

```bash
curl -s --connect-timeout 5 https://example.com
ping -c 3 -W 2 8.8.8.8
sudo apt-get update
```

**❓ Вопрос:** Все три команды зависнут/упадут. Объясни, почему на сетевом уровне: куда уходит пакет и почему ответ не приходит?

> **Подсказка:** Проверь маршруты VM: `ip route show`. Есть ли default gateway? Куда он ведёт? Что происходит с пакетом, когда он доходит до gateway VPC?

---

## Задание 3: Создание Cloud Router

**Цель:** подготовить Cloud Router — обязательный компонент для Cloud NAT.

Cloud NAT не работает сам по себе — ему нужен Cloud Router для управления маршрутами. Cloud Router — это виртуальный маршрутизатор, который реализует BGP и управляет динамической маршрутизацией в VPC.

```bash
gcloud compute routers create nat-lab-router \
    --network=nat-lab-vpc \
    --region=$REGION
```

**❓ Вопрос:** Cloud NAT в GCP — software-defined, он не создаёт отдельную VM. Зачем тогда нужен Cloud Router? Что он делает в контексте NAT?

---

## Задание 4: Настройка Cloud NAT

**Цель:** включить NAT и проверить, что приватная VM получила доступ в интернет.

**Шаг 1.** Создай Cloud NAT с автоматическим выделением IP:

```bash
gcloud compute routers nats create nat-lab-gateway \
    --router=nat-lab-router \
    --region=$REGION \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges \
    --enable-logging
```

> **Параметры:**
> - `--auto-allocate-nat-external-ips` — GCP сам выделит внешний IP
> - `--nat-all-subnet-ip-ranges` — NAT обслуживает все подсети в VPC
> - `--enable-logging` — включает журнал трансляций (пригодится позже)

**Шаг 2.** Подожди 1–2 минуты, затем проверь на VM:

```bash
# Подключись к VM (если отключился)
gcloud compute ssh nat-lab-vm --zone=$ZONE --tunnel-through-iap

# Проверь доступ
curl -s ifconfig.me
ping -c 3 8.8.8.8
curl -s https://example.com | head -20
```

**Шаг 3.** Узнай, через какой IP ты выходишь, и сравни с NAT Gateway:

```bash
# На VM
curl -s ifconfig.me
```

```bash
# В другом терминале (Cloud Shell)
gcloud compute routers nats describe nat-lab-gateway \
    --router=nat-lab-router \
    --region=$REGION
```

**❓ Вопрос:** IP, который показал ifconfig.me — он совпадает с natIpAllocateOption/natIps в описании NAT? Почему?

---

## Задание 5: Исследование NAT — порты, лимиты, поведение

**Цель:** понять, как Cloud NAT распределяет порты и что происходит при нагрузке.

### 5a. Проверка выделенных портов

```bash
# В Cloud Shell
gcloud compute routers get-nat-mapping-info nat-lab-router \
    --region=$REGION
```

Эта команда покажет, какие порты выделены каждой VM. По умолчанию — 64 порта на VM.

**❓ Вопрос:** 64 порта — это значит VM может одновременно иметь максимум 64 исходящих соединения к одному destination IP:port. Почему ограничение привязано к паре destination IP:port, а не просто к количеству соединений?

### 5b. Генерация нагрузки и наблюдение

На VM создай множество параллельных соединений:

```bash
# На VM: 50 параллельных запросов
for i in $(seq 1 50); do
    curl -s -o /dev/null -w "%{http_code} " https://httpbin.org/get &
done
wait
echo "Done"
```

Пока запросы идут, в Cloud Shell проверь маппинг:

```bash
gcloud compute routers get-nat-mapping-info nat-lab-router \
    --region=$REGION
```

### 5c. Увеличение лимита портов

Увеличь минимальное количество портов на VM:

```bash
gcloud compute routers nats update nat-lab-gateway \
    --router=nat-lab-router \
    --region=$REGION \
    --min-ports-per-vm=256
```

Проверь изменения:

```bash
gcloud compute routers get-nat-mapping-info nat-lab-router \
    --region=$REGION
```

**❓ Вопрос:** В продакшне с сотнями подов, каждый из которых обращается к одному внешнему API — какие проблемы возникнут с портами? Как решать?

### 5d. Статический IP для NAT

В продакшне часто нужен фиксированный исходящий IP (IP whitelisting). Переведи NAT на статический адрес:

```bash
# Зарезервируй статический IP
gcloud compute addresses create nat-lab-static-ip \
    --region=$REGION

# Посмотри выделенный адрес
gcloud compute addresses describe nat-lab-static-ip \
    --region=$REGION --format='value(address)'

# Переключи NAT на статический IP
gcloud compute routers nats update nat-lab-gateway \
    --router=nat-lab-router \
    --region=$REGION \
    --nat-external-ip-pool=nat-lab-static-ip
```

Проверь на VM:

```bash
curl -s ifconfig.me
```

**❓ Вопрос:** Теперь IP совпадает с зарезервированным? Что произойдёт, если удалить этот статический адрес, не обновив NAT?

---

## Задание 6: NAT-логи и мониторинг

**Цель:** научиться читать логи Cloud NAT и настроить мониторинг.

**Шаг 1.** Сгенерируй трафик на VM:

```bash
# На VM
for i in $(seq 1 10); do curl -s -o /dev/null https://example.com; done
curl -s -o /dev/null https://httpbin.org/get
curl -s -o /dev/null https://icanhazip.com
```

**Шаг 2.** Подожди 2–3 минуты и посмотри логи (в Cloud Shell):

```bash
gcloud logging read \
    'resource.type="nat_gateway"
    AND logName="projects/'$PROJECT_ID'/logs/compute.googleapis.com%2Fnat_flows"' \
    --limit=10 \
    --format=json
```

**Шаг 3.** Посмотри метрики NAT:

```bash
# Количество активных соединений
gcloud monitoring metrics list \
    --filter='metric.type = starts_with("compute.googleapis.com/nat")'
```

> **Что смотреть в логах:** source IP и port VM (приватный адрес), translated IP и port (внешний адрес NAT), destination IP и port (куда шёл трафик), протокол и статус трансляции.

**❓ Вопрос:** Какие метрики Cloud NAT критически важно мониторить в продакшне? Что сигнализирует о проблемах?

---

## Задание 7: Очистка ресурсов

> ⚠️ **Важно:** удали все ресурсы, чтобы не платить за них. Удаляй в обратном порядке (зависимости).

```bash
# 1. NAT
gcloud compute routers nats delete nat-lab-gateway \
    --router=nat-lab-router --region=$REGION --quiet

# 2. Cloud Router
gcloud compute routers delete nat-lab-router \
    --region=$REGION --quiet

# 3. VM
gcloud compute instances delete nat-lab-vm \
    --zone=$ZONE --quiet

# 4. Firewall
gcloud compute firewall-rules delete nat-lab-allow-iap-ssh --quiet

# 5. Статический IP
gcloud compute addresses delete nat-lab-static-ip \
    --region=$REGION --quiet

# 6. Подсеть
gcloud compute networks subnets delete nat-lab-subnet \
    --region=$REGION --quiet

# 7. VPC
gcloud compute networks delete nat-lab-vpc --quiet
```

**❓ Вопрос:** Почему порядок удаления важен? Что произойдёт, если попытаться удалить VPC до удаления подсети и VM?

---

## Чеклист выполнения

- [ ] VPC и подсеть созданы в custom mode
- [ ] Firewall для IAP SSH настроен
- [ ] VM без публичного IP создана и доступна через IAP
- [ ] Без NAT интернет недоступен (curl/ping таймаутятся)
- [ ] Cloud Router создан
- [ ] Cloud NAT настроен, VM получила доступ в интернет
- [ ] `curl ifconfig.me` показывает IP NAT Gateway
- [ ] Маппинг портов просмотрен через `get-nat-mapping-info`
- [ ] Лимит портов увеличен до 256
- [ ] NAT переключён на статический IP
- [ ] Логи NAT прочитаны и разобраны
- [ ] Все ресурсы удалены

---

## Ответы на вопросы (для самопроверки)

**Задание 1 — subnet-mode=custom vs auto:** В auto-режиме GCP создаёт подсеть в каждом регионе с предопределёнными диапазонами. Custom даёт полный контроль: ты решаешь, в каких регионах будут подсети и с какими CIDR. Для продакшна всегда custom — иначе получишь пересечение адресов при VPC peering.

**Задание 2 — почему нет интернета:** У VM есть default route (0.0.0.0/0 через gateway VPC), пакет уходит, но на границе VPC некому сделать SNAT — у VM нет публичного IP, NAT нет. Для ICMP (ping) и TCP (curl) пакет просто дропается на выходе из VPC, ответ никогда не придёт.

**Задание 3 — роль Cloud Router:** Cloud Router управляет программируемыми маршрутами через BGP. Cloud NAT использует его инфраструктуру для внедрения NAT-правил в SDN-стек Andromeda. Без Router нет точки управления маршрутизацией.

**Задание 4 — совпадение IP:** Да, IP из ifconfig.me совпадает с NAT IP — это и есть SNAT в действии. VM отправляет пакет с source 10.0.1.x, Cloud NAT подменяет его на свой внешний IP, внешний сервер видит именно этот адрес.

**Задание 5a — привязка к destination:** NAT-маппинг определяется пятёркой (src_ip, src_port, dst_ip, dst_port, proto). 64 порта ограничивают соединения к одному конкретному destination IP:port. К разным destination можно переиспользовать те же порты.

**Задание 5d — удаление статического IP:** NAT сломается — трансляция прекратится, все исходящие соединения упадут. GCP не даст удалить IP, пока он используется ресурсом, но если принудительно — NAT перестанет работать до назначения нового IP.

**Задание 6 — критичные метрики:** `allocated_ports` (использование портов), `dropped_sent_packets_count` (дропы = port exhaustion или другие лимиты), `new_connections_count` (аномалии трафика). Алерт на dropped packets — первый признак проблем.

**Задание 7 — порядок удаления:** GCP не позволит удалить ресурс, от которого зависят другие. VPC нельзя удалить, пока в ней есть подсети, VM, firewall-правила. Удаление идёт от листьев к корню зависимостей.
