# 🛡️ Project Aegis: B2B Reconciliation & Ledger Platform

> **Статус:** Phase 0 (Infrastructure & Hygiene) завершена. Переходим к Phase 1 (Прототип приложения).

Aegis — это B2B SaaS-платформа для fintech-компаний, предназначенная для нормализации транзакционных потоков, мэтчинга и ведения двойной записи (Double-entry Ledger). Подробное бизнес-обоснование и план развития описаны в [План продукта (PROJECT_PLAN.md)](docs/PROJECT_PLAN.md).

Этот репозиторий содержит **полностью автоматизированную инфраструктуру** для работы платформы, реализующую паттерны Enterprise-уровня.

---

## 🏗 Архитектура Инфраструктуры

Мы используем гибридный подход: Ingress и Stateless сервисы работают в песочницах (future Kubernetes), а Stateful-слой (Базы данных и Message Brokers) вынесен на классическое ВМ-развертывание со строгой изоляцией дисковой подсистемы (LVM/RAID) и глубоким тюнингом ядра (BBR, THP, Page Cache).

- **Multi-Region:** Инфраструктура развернута в 3 регионах Azure.
- **Zero-Trust Mesh:** Все 5 узлов общаются исключительно через зашифрованный **WireGuard** оверлей (`10.100.0.0/24`). Никакие порты баз данных не "смотрят" даже во внутреннюю VNet сеть.
- **Observability:** VictoriaMetrics и Grafana развернуты из коробки для сбора системных метрик (`node_exporter`).

> 📚 **Техническая документация (SSOT)**
> - [Топология и IP-адресация](docs/topology.md)
> - [Каталог открытых портов](docs/ports.md)
> - [Архитектурные решения (ADR)](docs/adr/README.md)

---

## 🚀 Быстрый старт (Deployment)

Вся инфраструктура полностью управляется через IaC (Terraform + Ansible). Ручные операции запрещены.

### 1. Поднятие облачных ресурсов (Terraform)
Terraform создаст VNet, пиринги (Full Mesh) и 5 виртуальных машин с нужным количеством дисков.
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### 2. Конфигурация узлов (Ansible)
Ansible раскатает LVM/RAID, настроит ядро, поднимет WireGuard mesh и установит все базы данных (PostgreSQL, MongoDB, Redis, Kafka, etcd).
Развертывание оптимизировано (SSH Pipelining, Forks=20) и устойчиво к изменениям имен дисков (LUN discovery).

```bash
cd ../ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

---

## 🔑 Доступ к серверам (Bastion SSH)

Публичный IP есть **только у балансировщика (`az-app`)**. Все остальные серверы скрыты за NAT. Доступ к ним осуществляется через `ProxyJump` (`-J`). 

*IP бастиона подставьте из вывода `terraform output` (или посмотрите в Azure).*

**1. Доступ на бастион (az-app / Ingress / Monitoring):**
```bash
ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new ansible_user@<AZ_APP_PUBLIC_IP>
```

**2. Доступ к Базам Данных (az-db):**
```bash
ssh -i ~/.ssh/id_ed25519 -J ansible_user@<AZ_APP_PUBLIC_IP> -o StrictHostKeyChecking=accept-new ansible_user@10.10.1.5
```

**3. Доступ к Message Broker (az-kafka):**
```bash
ssh -i ~/.ssh/id_ed25519 -J ansible_user@<AZ_APP_PUBLIC_IP> -o StrictHostKeyChecking=accept-new ansible_user@10.11.1.4
```

**4. Доступ к Coordination (az-etcd):**
```bash
ssh -i ~/.ssh/id_ed25519 -J ansible_user@<AZ_APP_PUBLIC_IP> -o StrictHostKeyChecking=accept-new ansible_user@10.11.1.5
```

**5. Доступ к Archive/Backups (az-storage):**
```bash
ssh -i ~/.ssh/id_ed25519 -J ansible_user@<AZ_APP_PUBLIC_IP> -o StrictHostKeyChecking=accept-new ansible_user@10.12.1.4
```

> **Полезные UI интерфейсы (через SSH туннель к бастиону):**
> - **Grafana:** `http://localhost:3000`
> - **Aegis API (Sandbox):** `http://localhost:8080`
