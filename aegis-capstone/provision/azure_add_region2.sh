#!/usr/bin/env bash
set -e

# Region 1 (Existing)
RG1_NAME="rg-aegis-v3"
VNET1_NAME="vnet-aegis"

# Region 2 (New)
RG2_NAME="rg-aegis-r2"
LOCATION2="australiasoutheast"
VNET2_NAME="vnet-aegis-r2"
SUBNET2_APP="snet-app-r2"
ADMIN_USER="ansible_user"

echo "=== 1. Создание Resource Group для Региона 2 ($LOCATION2) ==="
az group create --name $RG2_NAME --location $LOCATION2 > /dev/null

echo "=== 2. Создание VNet и Подсети для Региона 2 ==="
# Используем 10.20.0.0/16 во избежание конфликтов IP
az network vnet create -g $RG2_NAME -n $VNET2_NAME --address-prefix 10.20.0.0/16 -l $LOCATION2 \
  --subnet-name $SUBNET2_APP --subnet-prefix 10.20.1.0/24 > /dev/null

echo "=== 3. Создание виртуальных машин в Регионе 2 ==="
echo "--> Создаем kafka-node (Apache Kafka KRaft, RAID 5)..."
az vm create -g $RG2_NAME -n kafka-node --image Ubuntu2204 --size Standard_D2s_v5 \
  --vnet-name $VNET2_NAME --subnet $SUBNET2_APP --admin-username $ADMIN_USER --ssh-key-values ~/.ssh/id_rsa.pub \
  --public-ip-address "" --nsg "" --data-disk-sizes-gb 10 10 10 --no-wait > /dev/null

echo "--> Создаем monitor-node (VictoriaMetrics + Grafana)..."
az vm create -g $RG2_NAME -n monitor-node --image Ubuntu2204 --size Standard_D2s_v5 \
  --vnet-name $VNET2_NAME --subnet $SUBNET2_APP --admin-username $ADMIN_USER --ssh-key-values ~/.ssh/id_rsa.pub \
  --public-ip-address "" --nsg "" --data-disk-sizes-gb 15 --no-wait > /dev/null

echo "=== 4. Настройка Global VNet Peering (Магистральный мост) ==="
# Получаем ID сетей
VNET1_ID=$(az network vnet show -g $RG1_NAME -n $VNET1_NAME --query id -o tsv)
VNET2_ID=$(az network vnet show -g $RG2_NAME -n $VNET2_NAME --query id -o tsv)

echo "--> Связываем VNet1 с VNet2..."
az network vnet peering create -g $RG1_NAME -n Peer-Region1-to-Region2 \
  --vnet-name $VNET1_NAME --remote-vnet $VNET2_ID --allow-vnet-access > /dev/null

echo "--> Связываем VNet2 с VNet1..."
az network vnet peering create -g $RG2_NAME -n Peer-Region2-to-Region1 \
  --vnet-name $VNET2_NAME --remote-vnet $VNET1_ID --allow-vnet-access > /dev/null

echo "Ждем выделения IP-адресов..."
sleep 30

KAFKA_IP=$(az vm show -d -g $RG2_NAME -n kafka-node --query privateIps -o tsv)
MONITOR_IP=$(az vm show -d -g $RG2_NAME -n monitor-node --query privateIps -o tsv)

echo "=== ИНФРАСТРУКТУРА РЕГИОНА 2 ГОТОВА ==="
echo "Kafka Node (Private Region 2): $KAFKA_IP"
echo "Monitor Node (Private Region 2): $MONITOR_IP"

echo "Добавьте в свой ~/.ssh/config (через тот же Бастион/App в Регионе 1):"
echo "
Host aegis-kafka
    HostName $KAFKA_IP
    User $ADMIN_USER
    ProxyJump aegis-app

Host aegis-monitor
    HostName $MONITOR_IP
    User $ADMIN_USER
    ProxyJump aegis-app
"
