#!/usr/bin/env bash
# Внимание: Перед запуском убедитесь, что вы авторизованы в Azure (az login)
set -e

RG_NAME="rg-aegis-prod"
LOCATION="westeurope"
VNET_NAME="vnet-aegis"
SUBNET_DMZ="snet-dmz"
SUBNET_APP="snet-app"
ADMIN_USER="ansible_user"
MY_IP=$(curl -s ifconfig.me)

echo "=== 1. Создание Resource Group ==="
az group create --name $RG_NAME --location $LOCATION

echo "=== 2. Создание VNet и Подсетей ==="
az network vnet create -g $RG_NAME -n $VNET_NAME --address-prefix 10.10.0.0/16 -l $LOCATION \
  --subnet-name $SUBNET_DMZ --subnet-prefix 10.10.1.0/24
az network vnet subnet create -g $RG_NAME --vnet-name $VNET_NAME -n $SUBNET_APP --address-prefixes 10.10.2.0/24

echo "=== 3. Настройка NSG для DMZ ==="
az network nsg create -g $RG_NAME -n nsg-bastion
az network nsg rule create -g $RG_NAME --nsg-name nsg-bastion -n Allow-SSH-My-IP \
  --priority 100 --source-address-prefixes $MY_IP --destination-port-ranges 22 --access Allow --protocol Tcp
az network vnet subnet update -g $RG_NAME --vnet-name $VNET_NAME -n $SUBNET_DMZ --network-security-group nsg-bastion

echo "=== 4. Развертывание Кластера (Bastion, App, DB, Kafka) ==="
# 4.1. Bastion (Public IP)
az vm create -g $RG_NAME -n bastion-host --image Ubuntu2204 --size Standard_B1s \
  --vnet-name $VNET_NAME --subnet $SUBNET_DMZ --admin-username $ADMIN_USER --generate-ssh-keys \
  --public-ip-sku Standard --nsg "" --no-wait

# 4.2. App Node (Nginx + Containerd. Future K8s Worker/CP)
az vm create -g $RG_NAME -n app-node --image Ubuntu2204 --size Standard_B1s \
  --vnet-name $VNET_NAME --subnet $SUBNET_APP --admin-username $ADMIN_USER --ssh-key-values ~/.ssh/id_rsa.pub \
  --public-ip-address "" --nsg "" --no-wait

# 4.3. DB Node (PostgreSQL + Redis + MongoDB). Увеличили диски до 20GB под зоопарк БД.
az vm create -g $RG_NAME -n db-node --image Ubuntu2204 --size Standard_B2s \
  --vnet-name $VNET_NAME --subnet $SUBNET_APP --admin-username $ADMIN_USER --ssh-key-values ~/.ssh/id_rsa.pub \
  --public-ip-address "" --nsg "" --data-disk-sizes-gb 20 20 --no-wait

# 4.4. Kafka Node (Apache Kafka KRaft). 3 диска под RAID 5.
az vm create -g $RG_NAME -n kafka-node --image Ubuntu2204 --size Standard_B2s \
  --vnet-name $VNET_NAME --subnet $SUBNET_APP --admin-username $ADMIN_USER --ssh-key-values ~/.ssh/id_rsa.pub \
  --public-ip-address "" --nsg "" --data-disk-sizes-gb 10 10 10

echo "=== ИНФРАСТРУКТУРА ГОТОВА ==="
BASTION_IP=$(az vm show -d -g $RG_NAME -n bastion-host --query publicIps -o tsv)
APP_IP=$(az vm show -d -g $RG_NAME -n app-node --query privateIps -o tsv)
DB_IP=$(az vm show -d -g $RG_NAME -n db-node --query privateIps -o tsv)
KAFKA_IP=$(az vm show -d -g $RG_NAME -n kafka-node --query privateIps -o tsv)

echo "Добавьте в свой ~/.ssh/config:"
echo "
Host aegis-bastion
    HostName $BASTION_IP
    User $ADMIN_USER

Host aegis-app
    HostName $APP_IP
    User $ADMIN_USER
    ProxyJump aegis-bastion

Host aegis-db
    HostName $DB_IP
    User $ADMIN_USER
    ProxyJump aegis-bastion

Host aegis-kafka
    HostName $KAFKA_IP
    User $ADMIN_USER
    ProxyJump aegis-bastion
"
