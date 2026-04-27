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

# Функция для создания VM с перебором размеров (Fallback)
# usage: create_vm_with_fallback <name> <subnet> <public_ip_args> <data_disks_args> <size1> <size2> ...
create_vm_with_fallback() {
    local name=$1
    local subnet=$2
    local public_ip_args=$3
    local data_disks_args=$4
    shift 4
    local sizes=("$@")
    
    for size in "${sizes[@]}"; do
        echo "--> Пробуем создать $name с размером $size..."
        
        # Формируем базовую команду
        local cmd="az vm create -g $RG_NAME -n $name --image Ubuntu2204 --size $size --vnet-name $VNET_NAME --subnet $subnet --admin-username $ADMIN_USER --ssh-key-values ~/.ssh/id_rsa.pub --nsg \"\""
        
        # Добавляем аргументы публичного IP, если они есть
        if [ -n "$public_ip_args" ]; then
            cmd="$cmd $public_ip_args"
        else
            cmd="$cmd --public-ip-address \"\""
        fi
        
        # Добавляем аргументы дисков, если они есть
        if [ -n "$data_disks_args" ]; then
            cmd="$cmd $data_disks_args"
        fi
        
        if eval "$cmd" > /dev/null 2>&1; then
            echo "✅ Успех: $name создан ($size)"
            return 0
        else
            echo "❌ Ошибка: Не удалось создать $name ($size). Пробуем следующий размер..."
        fi
    done
    
    echo "🚨 КРИТИЧЕСКАЯ ОШИБКА: Не удалось создать $name ни с одним из размеров!"
    return 1
}


echo "=== 1. Создание Resource Group ==="
az group create --name $RG_NAME --location $LOCATION > /dev/null

echo "=== 2. Создание VNet и Подсетей ==="
az network vnet create -g $RG_NAME -n $VNET_NAME --address-prefix 10.10.0.0/16 -l $LOCATION \
  --subnet-name $SUBNET_DMZ --subnet-prefix 10.10.1.0/24 > /dev/null
az network vnet subnet create -g $RG_NAME --vnet-name $VNET_NAME -n $SUBNET_APP --address-prefixes 10.10.2.0/24 > /dev/null

echo "=== 3. Настройка NSG для DMZ ==="
az network nsg create -g $RG_NAME -n nsg-bastion > /dev/null
az network nsg rule create -g $RG_NAME --nsg-name nsg-bastion -n Allow-SSH-My-IP \
  --priority 100 --source-address-prefixes $MY_IP --destination-port-ranges 22 --access Allow --protocol Tcp > /dev/null
az network vnet subnet update -g $RG_NAME --vnet-name $VNET_NAME -n $SUBNET_DMZ --network-security-group nsg-bastion > /dev/null

echo "=== 4. Развертывание Кластера (Перебор размеров из-за ограничений Azure) ==="

# Bastion (идеально 1 vCPU, можно самый слабый)
create_vm_with_fallback "bastion-host" "$SUBNET_DMZ" "--public-ip-sku Standard" "" "Standard_B1ls" "Standard_B1s" "Standard_B2ats_v2"

# DB Node (идеально 2 vCPU, 8 RAM, 4 диска)
create_vm_with_fallback "db-node" "$SUBNET_APP" "" "--data-disk-sizes-gb 10 10 10 10" "Standard_B2ms" "Standard_B2s" "Standard_B2pts_v2"

# App & Observability Node (идеально 1 vCPU, 1 диск для Kafka/VictoriaMetrics)
create_vm_with_fallback "app-node" "$SUBNET_APP" "" "--data-disk-sizes-gb 15" "Standard_B1s" "Standard_B1ms" "Standard_B2s"


echo "=== ИНФРАСТРУКТУРА ГОТОВА ==="
BASTION_IP=$(az vm show -d -g $RG_NAME -n bastion-host --query publicIps -o tsv)
APP_IP=$(az vm show -d -g $RG_NAME -n app-node --query privateIps -o tsv)
DB_IP=$(az vm show -d -g $RG_NAME -n db-node --query privateIps -o tsv)

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
"
