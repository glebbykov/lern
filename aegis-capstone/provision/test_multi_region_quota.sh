#!/usr/bin/env bash
set -e

# Убедимся, что старых групп нет
az group delete --name rg-test-eastus --yes --no-wait 2>/dev/null || true
az group delete --name rg-test-eastus2 --yes --no-wait 2>/dev/null || true
az group delete --name rg-test-centralus --yes --no-wait 2>/dev/null || true

echo "=== Создаем ресурсные группы в 3-х регионах США ==="
az group create --name rg-test-eastus --location eastus >/dev/null
az group create --name rg-test-eastus2 --location eastus2 >/dev/null
az group create --name rg-test-centralus --location centralus >/dev/null

echo "=== Запрашиваем виртуалки (Асинхронно) ==="
# East US: 3 vCPU total (B1s=1, B2ms=2)
echo "1. Запуск bastion (eastus, B1s, 1 vCPU)"
az vm create -g rg-test-eastus -n test-bastion --image Ubuntu2204 --size Standard_B1s --admin-username azureuser --generate-ssh-keys --no-wait >/dev/null
echo "2. Запуск db-node (eastus, B2ms, 2 vCPU)"
az vm create -g rg-test-eastus -n test-db --image Ubuntu2204 --size Standard_B2ms --admin-username azureuser --generate-ssh-keys --no-wait >/dev/null

# East US 2: 4 vCPU total (B2ms=2, B2ms=2)
echo "3. Запуск kafka-node (eastus2, B2ms, 2 vCPU)"
az vm create -g rg-test-eastus2 -n test-kafka --image Ubuntu2204 --size Standard_B2ms --admin-username azureuser --generate-ssh-keys --no-wait >/dev/null
echo "4. Запуск monitor-node (eastus2, B2ms, 2 vCPU)"
az vm create -g rg-test-eastus2 -n test-monitor --image Ubuntu2204 --size Standard_B2ms --admin-username azureuser --generate-ssh-keys --no-wait >/dev/null

# Central US: 2 vCPU total (B2s=2)
echo "5. Запуск app-node (centralus, B2s, 2 vCPU)"
az vm create -g rg-test-centralus -n test-app --image Ubuntu2204 --size Standard_B2s --admin-username azureuser --generate-ssh-keys --no-wait >/dev/null

echo "Запросы отправлены. Ждем 45 секунд..."
sleep 45

echo "=== Результаты проверки состояния ВМ ==="
az vm list -d --query "[].{Name:name, Region:location, Size:hardwareProfile.vmSize, State:provisioningState}" -o table

