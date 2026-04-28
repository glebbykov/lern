import os

TF_DIR = "/root/lern/aegis-capstone/terraform"
os.makedirs(f"{TF_DIR}/.generated", exist_ok=True)
os.makedirs("/root/lern/aegis-capstone/ansible/inventory/host_vars", exist_ok=True)

# ... (var_hcl and azure_hcl are exactly the same as above) ...
var_hcl = """
variable "project_name" { default = "aegis-v4" }
variable "operator_ip" {}
variable "ssh_public_key_path" { default = "~/.ssh/id_ed25519.pub" }
variable "vm_admin_user" { default = "ansible_user" }
variable "azure_subscription_id" {}
variable "azure_location_1" { default = "australiaeast" }
variable "azure_location_2" { default = "australiasoutheast" }
variable "azure_location_3" { default = "southeastasia" }
variable "azure_vm_size" { default = "Standard_D2s_v5" }
"""

azure_hcl = """
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.azure_subscription_id
}

resource "azurerm_resource_group" "r1" {
  name     = "${var.project_name}-az-r1"
  location = var.azure_location_1
}

resource "azurerm_resource_group" "r2" {
  name     = "${var.project_name}-az-r2"
  location = var.azure_location_2
}

resource "azurerm_resource_group" "r3" {
  name     = "${var.project_name}-az-r3"
  location = var.azure_location_3
}

resource "azurerm_virtual_network" "v1" {
  name                = "vnet-r1"
  location            = azurerm_resource_group.r1.location
  resource_group_name = azurerm_resource_group.r1.name
  address_space       = ["10.10.0.0/16"]
}

resource "azurerm_virtual_network" "v2" {
  name                = "vnet-r2"
  location            = azurerm_resource_group.r2.location
  resource_group_name = azurerm_resource_group.r2.name
  address_space       = ["10.11.0.0/16"]
}

resource "azurerm_virtual_network" "v3" {
  name                = "vnet-r3"
  location            = azurerm_resource_group.r3.location
  resource_group_name = azurerm_resource_group.r3.name
  address_space       = ["10.12.0.0/16"]
}

resource "azurerm_virtual_network_peering" "p12" {
  name                         = "p12"
  resource_group_name          = azurerm_resource_group.r1.name
  virtual_network_name         = azurerm_virtual_network.v1.name
  remote_virtual_network_id    = azurerm_virtual_network.v2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "p21" {
  name                         = "p21"
  resource_group_name          = azurerm_resource_group.r2.name
  virtual_network_name         = azurerm_virtual_network.v2.name
  remote_virtual_network_id    = azurerm_virtual_network.v1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "p13" {
  name                         = "p13"
  resource_group_name          = azurerm_resource_group.r1.name
  virtual_network_name         = azurerm_virtual_network.v1.name
  remote_virtual_network_id    = azurerm_virtual_network.v3.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "p31" {
  name                         = "p31"
  resource_group_name          = azurerm_resource_group.r3.name
  virtual_network_name         = azurerm_virtual_network.v3.name
  remote_virtual_network_id    = azurerm_virtual_network.v1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_subnet" "s1" {
  name                 = "sub1"
  resource_group_name  = azurerm_resource_group.r1.name
  virtual_network_name = azurerm_virtual_network.v1.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "s2" {
  name                 = "sub2"
  resource_group_name  = azurerm_resource_group.r2.name
  virtual_network_name = azurerm_virtual_network.v2.name
  address_prefixes     = ["10.11.1.0/24"]
}

resource "azurerm_subnet" "s3" {
  name                 = "sub3"
  resource_group_name  = azurerm_resource_group.r3.name
  virtual_network_name = azurerm_virtual_network.v3.name
  address_prefixes     = ["10.12.1.0/24"]
}

resource "azurerm_public_ip" "app" {
  name                = "pip-app"
  location            = azurerm_resource_group.r1.location
  resource_group_name = azurerm_resource_group.r1.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "nsg1" {
  name                = "nsg1"
  location            = azurerm_resource_group.r1.location
  resource_group_name = azurerm_resource_group.r1.name
  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.operator_ip
    source_port_range          = "*"
    destination_port_range     = "22"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefixes    = ["10.0.0.0/8"]
    source_port_range          = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_internal" {
  for_each            = { r2 = azurerm_resource_group.r2, r3 = azurerm_resource_group.r3 }
  name                = "nsg-${each.key}"
  location            = each.value.location
  resource_group_name = each.value.name
  security_rule {
    name                       = "internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefixes    = ["10.0.0.0/8"]
    source_port_range          = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "a1" {
  subnet_id                 = azurerm_subnet.s1.id
  network_security_group_id = azurerm_network_security_group.nsg1.id
}

resource "azurerm_subnet_network_security_group_association" "a2" {
  subnet_id                 = azurerm_subnet.s2.id
  network_security_group_id = azurerm_network_security_group.nsg_internal["r2"].id
}

resource "azurerm_subnet_network_security_group_association" "a3" {
  subnet_id                 = azurerm_subnet.s3.id
  network_security_group_id = azurerm_network_security_group.nsg_internal["r3"].id
}

locals {
  az_vms = {
    app     = { rg = azurerm_resource_group.r1, sub = azurerm_subnet.s1.id, pip = azurerm_public_ip.app.id, disks = { monitor = { lun = 0, size = 16 } } }
    db      = { rg = azurerm_resource_group.r1, sub = azurerm_subnet.s1.id, pip = null, disks = { pgsql = { lun = 0, size = 16 }, mongo = { lun = 1, size = 16 }, redis = { lun = 2, size = 16 } } }
    kafka   = { rg = azurerm_resource_group.r2, sub = azurerm_subnet.s2.id, pip = null, disks = { jbod0 = { lun = 0, size = 16 }, jbod1 = { lun = 1, size = 16 } } }
    etcd    = { rg = azurerm_resource_group.r2, sub = azurerm_subnet.s2.id, pip = null, disks = { etcd = { lun = 0, size = 16 } } }
    storage = { rg = azurerm_resource_group.r3, sub = azurerm_subnet.s3.id, pip = null, disks = { raid0 = { lun = 0, size = 16 }, raid1 = { lun = 1, size = 16 }, raid2 = { lun = 2, size = 16 } } }
  }
  az_disks_flat = flatten([
    for vm_k, vm_v in local.az_vms : [
      for d_k, d_v in vm_v.disks : {
        vm   = vm_k
        disk = d_k
        lun  = d_v.lun
        size = d_v.size
        rg   = vm_v.rg
      }
    ]
  ])
}

resource "azurerm_network_interface" "nics" {
  for_each            = local.az_vms
  name                = "nic-${each.key}"
  location            = each.value.rg.location
  resource_group_name = each.value.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.sub
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = each.value.pip
  }
}

resource "azurerm_linux_virtual_machine" "vms" {
  for_each                        = local.az_vms
  name                            = "az-${each.key}"
  resource_group_name             = each.value.rg.name
  location                        = each.value.rg.location
  size                            = var.azure_vm_size
  admin_username                  = var.vm_admin_user
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.nics[each.key].id]

  admin_ssh_key {
    username   = var.vm_admin_user
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    offer     = "0001-com-ubuntu-server-jammy"
    publisher = "Canonical"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_managed_disk" "disks" {
  for_each             = { for d in local.az_disks_flat : "${d.vm}-${d.disk}" => d }
  name                 = "disk-${each.key}"
  location             = each.value.rg.location
  resource_group_name  = each.value.rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = each.value.size
}

resource "azurerm_virtual_machine_data_disk_attachment" "atts" {
  for_each           = { for d in local.az_disks_flat : "${d.vm}-${d.disk}" => d }
  managed_disk_id    = azurerm_managed_disk.disks[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.vms[each.value.vm].id
  lun                = each.value.lun
  caching            = "ReadWrite"
}
"""

inventory_hcl = """
resource "local_file" "inventory" {
  filename = "../ansible/inventory/hosts.ini"
  content  = <<-EOT
    [app_nodes]
    az-app ansible_host=$${azurerm_public_ip.app.ip_address}

    [monitor_nodes]
    az-app

    [db_nodes]
    az-db ansible_host=$${azurerm_network_interface.nics["db"].private_ip_address}

    [kafka_nodes]
    az-kafka ansible_host=$${azurerm_network_interface.nics["kafka"].private_ip_address}

    [etcd_nodes]
    az-etcd ansible_host=$${azurerm_network_interface.nics["etcd"].private_ip_address}

    [storage_nodes]
    az-storage ansible_host=$${azurerm_network_interface.nics["storage"].private_ip_address}

    [azure_nodes]
    az-app
    az-db
    az-kafka
    az-etcd
    az-storage

    [all:vars]
    ansible_user=$${var.vm_admin_user}
    ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null'
  EOT
}

resource "local_file" "ssh_config" {
  filename        = ".generated/ssh_config"
  file_permission = "0600"
  content         = <<-EOT
    Host az-app
        HostName $${azurerm_public_ip.app.ip_address}
        User $${var.vm_admin_user}
        StrictHostKeyChecking accept-new
    Host az-*
        ProxyJump az-app
        User $${var.vm_admin_user}
        StrictHostKeyChecking accept-new
  EOT
}

resource "local_file" "hv_az_app" {
  filename = "../ansible/inventory/host_vars/az-app.yml"
  content  = yamlencode({
    aegis_cloud = "azure",
    aegis_data_devices = [
      { name = "monitor", dev = "/dev/sdc", fs = "xfs", mount = "/var/lib/victoria-metrics-data" }
    ],
    aegis_raid_devices = []
  })
}

resource "local_file" "hv_az_db" {
  filename = "../ansible/inventory/host_vars/az-db.yml"
  content  = yamlencode({
    aegis_cloud = "azure",
    aegis_data_devices = [
      { name = "pgsql", dev = "/dev/sdc", fs = "ext4", mount = "/var/lib/postgresql" },
      { name = "mongo", dev = "/dev/sdd", fs = "xfs", mount = "/var/lib/mongodb" },
      { name = "redis", dev = "/dev/sde", fs = "ext4", mount = "/var/lib/redis" }
    ],
    aegis_raid_devices = []
  })
}

resource "local_file" "hv_az_kafka" {
  filename = "../ansible/inventory/host_vars/az-kafka.yml"
  content  = yamlencode({
    aegis_cloud = "azure",
    aegis_data_devices = [
      { name = "kafka_jbod0", dev = "/dev/sdc", fs = "xfs", mount = "/var/lib/kafka/data0" },
      { name = "kafka_jbod1", dev = "/dev/sdd", fs = "xfs", mount = "/var/lib/kafka/data1" }
    ],
    aegis_raid_devices = []
  })
}

resource "local_file" "hv_az_etcd" {
  filename = "../ansible/inventory/host_vars/az-etcd.yml"
  content  = yamlencode({
    aegis_cloud = "azure",
    aegis_data_devices = [
      { name = "etcd", dev = "/dev/sdc", fs = "ext4", mount = "/var/lib/etcd" }
    ],
    aegis_raid_devices = []
  })
}

resource "local_file" "hv_az_storage" {
  filename = "../ansible/inventory/host_vars/az-storage.yml"
  content  = yamlencode({
    aegis_cloud = "azure",
    aegis_data_devices = [
      { name = "backups", dev = "/dev/md0", fs = "xfs", mount = "/mnt/backups" }
    ],
    aegis_raid_devices = ["/dev/sdc", "/dev/sdd", "/dev/sde"]
  })
}
"""

with open(f"{TF_DIR}/variables.tf", "w") as f: f.write(var_hcl)
with open(f"{TF_DIR}/azure.tf", "w") as f: f.write(azure_hcl)
with open(f"{TF_DIR}/inventory.tf", "w") as f: f.write(inventory_hcl)

if os.path.exists(f"{TF_DIR}/gcp.tf"):
    os.remove(f"{TF_DIR}/gcp.tf")
