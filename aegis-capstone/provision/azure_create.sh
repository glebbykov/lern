#!/usr/bin/env bash
set -e

RG_NAME="rg-aegis-v3"
LOCATION="australiaeast"
VNET_NAME="vnet-aegis"
SUBNET_APP="snet-app"
ADMIN_USER="ansible_user"
MY_IP=$(curl -s ifconfig.me)

echo "=== 1. Создание Resource Group ($LOCATION) ==="
az group create --name $RG_NAME --location $LOCATION > /dev/null

echo "=== 2. Создание VNet и Подсети ==="
az network vnet create -g $RG_NAME -n $VNET_NAME --address-prefix 10.10.0.0/16 -l $LOCATION \
  --subnet-name $SUBNET_APP --subnet-prefix 10.10.1.0/24 > /dev/null

echo "=== 3. Настройка NSG (Разрешаем SSH только вам) ==="
az network nsg create -g $RG_NAME -n nsg-aegis > /dev/null
az network nsg rule create -g $RG_NAME --nsg-name nsg-aegis -n Allow-SSH-My-IP \
  --priority 100 --source-address-prefixes $MY_IP --destination-port-ranges 22 --access Allow --protocol Tcp > /dev/null
az network vnet subnet update -g $RG_NAME --vnet-name $VNET_NAME -n $SUBNET_APP --network-security-group nsg-aegis > /dev/null

echo "=== 4. Развертывание 2-х нод (Серия D2s_v5 - 2+2 = 4 vCPU) ==="

echo "--> Создаем app-node (Nginx + Kafka + Monitoring + Bastion Role)..."
az vm create -g $RG_NAME -n app-node --image Ubuntu2204 --size Standard_D2s_v5 \
  --vnet-name $VNET_NAME --subnet $SUBNET_APP --admin-username $ADMIN_USER --generate-ssh-keys \
  --public-ip-sku Standard --nsg nsg-aegis --data-disk-sizes-gb 20 > /dev/null

echo "--> Создаем db-node (Postgres + Mongo + Redis + etcd)..."
az vm create -g $RG_NAME -n db-node --image Ubuntu2204 --size Standard_D2s_v5 \
  --vnet-name $VNET_NAME --subnet $SUBNET_APP --admin-username $ADMIN_USER --ssh-key-values ~/.ssh/id_rsa.pub \
  --public-ip-address "" --nsg "" --data-disk-sizes-gb 10 10 10 10 > /dev/null

echo "=== ИНФРАСТРУКТУРА ГОТОВА ==="
APP_IP=$(az vm show -d -g $RG_NAME -n app-node --query publicIps -o tsv)
DB_IP=$(az vm show -d -g $RG_NAME -n db-node --query privateIps -o tsv)

echo "App Node (Public): $APP_IP"
echo "DB Node (Private): $DB_IP"

echo "Добавьте в свой ~/.ssh/config:"
echo "
Host aegis-app
    HostName $APP_IP
    User $ADMIN_USER

Host aegis-db
    HostName $DB_IP
    User $ADMIN_USER
    ProxyJump aegis-app
"
