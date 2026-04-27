#!/usr/bin/env bash
# Внимание: Перед запуском убедитесь, что вы авторизованы в Azure (az login)
set -e

# Конфигурация
RG_NAME="rg-aegis-prod"
LOCATION="westeurope"
VNET_NAME="vnet-aegis"
SUBNET_DMZ="snet-dmz"
SUBNET_APP="snet-app"
ADMIN_USER="ansible_user"
# Получаем ваш публичный IP для настройки доступа к бастиону
MY_IP=$(curl -s ifconfig.me)

echo "=== 1. Создание Resource Group ==="
az group create --name $RG_NAME --location $LOCATION

echo "=== 2. Создание VNet и Подсетей ==="
az network vnet create -g $RG_NAME -n $VNET_NAME --address-prefix 10.10.0.0/16 -l $LOCATION \
  --subnet-name $SUBNET_DMZ --subnet-prefix 10.10.1.0/24
az network vnet subnet create -g $RG_NAME --vnet-name $VNET_NAME -n $SUBNET_APP --address-prefixes 10.10.2.0/24

echo "=== 3. Настройка NSG (Network Security Group) для DMZ ==="
az network nsg create -g $RG_NAME -n nsg-bastion
# Разрешаем SSH только с вашего IP
az network nsg rule create -g $RG_NAME --nsg-name nsg-bastion -n Allow-SSH-My-IP \
  --priority 100 --source-address-prefixes $MY_IP --destination-port-ranges 22 --access Allow --protocol Tcp
# Привязываем NSG к DMZ подсети
az network vnet subnet update -g $RG_NAME --vnet-name $VNET_NAME -n $SUBNET_DMZ --network-security-group nsg-bastion

echo "=== 4. Создание Bastion Host ==="
az vm create -g $RG_NAME -n bastion-host --image Ubuntu2204 --size Standard_B1s \
  --vnet-name $VNET_NAME --subnet $SUBNET_DMZ --admin-username $ADMIN_USER --generate-ssh-keys \
  --public-ip-sku Standard --nsg "" 

echo "=== 5. Создание Application Node (БЕЗ Public IP, с 2мя доп. дисками) ==="
az vm create -g $RG_NAME -n app-node --image Ubuntu2204 --size Standard_B2s \
  --vnet-name $VNET_NAME --subnet $SUBNET_APP --admin-username $ADMIN_USER --ssh-key-values ~/.ssh/id_rsa.pub \
  --public-ip-address "" --nsg "" --data-disk-sizes-gb 20 20

echo "=== ИНФРАСТРУКТУРА ГОТОВА ==="
BASTION_IP=$(az vm show -d -g $RG_NAME -n bastion-host --query publicIps -o tsv)
APP_NODE_IP=$(az vm show -d -g $RG_NAME -n app-node --query privateIps -o tsv)

echo "Bastion Public IP: $BASTION_IP"
echo "App Node Private IP: $APP_NODE_IP"

echo "Добавьте в свой ~/.ssh/config:"
echo "
Host aegis-bastion
    HostName $BASTION_IP
    User $ADMIN_USER

Host aegis-app
    HostName $APP_NODE_IP
    User $ADMIN_USER
    ProxyJump aegis-bastion
"
