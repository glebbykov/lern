import os

TF_DIR = "/root/lern/aegis-capstone/terraform"
os.makedirs(f"{TF_DIR}/.generated", exist_ok=True)
os.makedirs("/root/lern/aegis-capstone/ansible/inventory/host_vars", exist_ok=True)

var_hcl = """
variable "project_name" { default = "aegis" }
variable "operator_ip" {}
variable "ssh_public_key_path" { default = "~/.ssh/id_ed25519.pub" }
variable "vm_admin_user" { default = "ansible_user" }
variable "azure_subscription_id" {}
variable "azure_location_1" { default = "australiaeast" }
variable "azure_location_2" { default = "australiasoutheast" }
variable "azure_location_3" { default = "centralus" }
variable "azure_vm_size" { default = "Standard_D2s_v5" }
variable "gcp_project_id" {}
variable "gcp_region_1" { default = "us-central1" }
variable "gcp_zone_1" { default = "us-central1-a" }
variable "gcp_region_2" { default = "us-west1" }
variable "gcp_zone_2" { default = "us-west1-b" }
variable "gcp_machine_type" { default = "e2-standard-2" }
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

resource "azurerm_network_security_group" "nsg2" {
  name                = "nsg2"
  location            = azurerm_resource_group.r2.location
  resource_group_name = azurerm_resource_group.r2.name
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

resource "azurerm_network_security_group" "nsg3" {
  name                = "nsg3"
  location            = azurerm_resource_group.r3.location
  resource_group_name = azurerm_resource_group.r3.name
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
  network_security_group_id = azurerm_network_security_group.nsg2.id
}

resource "azurerm_subnet_network_security_group_association" "a3" {
  subnet_id                 = azurerm_subnet.s3.id
  network_security_group_id = azurerm_network_security_group.nsg3.id
}

locals {
  az_vms = {
    app     = { rg = azurerm_resource_group.r1, sub = azurerm_subnet.s1.id, pip = azurerm_public_ip.app.id, disks = { monitor = 0 } }
    db      = { rg = azurerm_resource_group.r1, sub = azurerm_subnet.s1.id, pip = null, disks = { pgsql = 0, mongo = 1, redis = 2 } }
    kafka   = { rg = azurerm_resource_group.r2, sub = azurerm_subnet.s2.id, pip = null, disks = { jbod0 = 0, jbod1 = 1 } }
    etcd    = { rg = azurerm_resource_group.r2, sub = azurerm_subnet.s2.id, pip = null, disks = { etcd = 0 } }
    storage = { rg = azurerm_resource_group.r3, sub = azurerm_subnet.s3.id, pip = null, disks = { raid0 = 0, raid1 = 1, raid2 = 2 } }
  }
  az_disks_flat = flatten([
    for vm_k, vm_v in local.az_vms : [
      for d_k, d_v in vm_v.disks : {
        vm   = vm_k
        disk = d_k
        lun  = d_v
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
  disk_size_gb         = 16
}

resource "azurerm_virtual_machine_data_disk_attachment" "atts" {
  for_each           = { for d in local.az_disks_flat : "${d.vm}-${d.disk}" => d }
  managed_disk_id    = azurerm_managed_disk.disks[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.vms[each.value.vm].id
  lun                = each.value.lun
  caching            = "ReadWrite"
}
"""

gcp_hcl = """
provider "google" {
  project = var.gcp_project_id
}

resource "google_compute_network" "vpc" {
  name                    = "gcp-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "sub1" {
  name          = "gcp-sub1"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.20.1.0/24"
  region        = var.gcp_region_1
}

resource "google_compute_subnetwork" "sub2" {
  name          = "gcp-sub2"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.21.1.0/24"
  region        = var.gcp_region_2
}

resource "google_compute_firewall" "ssh" {
  name          = "gcp-fw-ssh"
  network       = google_compute_network.vpc.id
  source_ranges = [var.operator_ip]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "internal" {
  name          = "gcp-fw-internal"
  network       = google_compute_network.vpc.id
  source_ranges = ["10.0.0.0/8"]
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

locals {
  gcp_vms = {
    app     = { zone = var.gcp_zone_1, sub = google_compute_subnetwork.sub1.id, pip = true, disks = { monitor = 16 } }
    db      = { zone = var.gcp_zone_1, sub = google_compute_subnetwork.sub1.id, pip = false, disks = { pgsql = 16, mongo = 16, redis = 16 } }
    kafka   = { zone = var.gcp_zone_2, sub = google_compute_subnetwork.sub2.id, pip = false, disks = { jbod0 = 16, jbod1 = 16 } }
    etcd    = { zone = var.gcp_zone_2, sub = google_compute_subnetwork.sub2.id, pip = false, disks = { etcd = 16 } }
    storage = { zone = var.gcp_zone_2, sub = google_compute_subnetwork.sub2.id, pip = false, disks = { raid0 = 16, raid1 = 16, raid2 = 16 } }
  }
  gcp_disks_flat = flatten([
    for vm_k, vm_v in local.gcp_vms : [
      for d_k, d_v in vm_v.disks : {
        vm   = vm_k
        disk = d_k
        size = d_v
        zone = vm_v.zone
      }
    ]
  ])
}

resource "google_compute_disk" "disks" {
  for_each = { for d in local.gcp_disks_flat : "${d.vm}-${d.disk}" => d }
  name     = "gcp-${each.key}"
  type     = "pd-ssd"
  zone     = each.value.zone
  size     = each.value.size
}

resource "google_compute_instance" "vms" {
  for_each     = local.gcp_vms
  name         = "gcp-${each.key}"
  machine_type = var.gcp_machine_type
  zone         = each.value.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = each.value.sub
    dynamic "access_config" {
      for_each = each.value.pip ? [1] : []
      content {}
    }
  }

  dynamic "attached_disk" {
    for_each = each.value.disks
    content {
      source      = google_compute_disk.disks["${each.key}-${attached_disk.key}"].id
      device_name = attached_disk.key
    }
  }

  metadata = {
    ssh-keys = "${var.vm_admin_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }
}
"""

inventory_hcl = """
resource "local_file" "inventory" {
  filename = "../ansible/inventory/hosts.ini"
  content  = <<-EOT
    [app_nodes]
    az-app ansible_host=$${azurerm_public_ip.app.ip_address}
    gcp-app ansible_host=$${google_compute_instance.vms["app"].network_interface[0].access_config[0].nat_ip}

    [db_nodes]
    az-db ansible_host=$${azurerm_network_interface.nics["db"].private_ip_address}
    gcp-db ansible_host=$${google_compute_instance.vms["db"].network_interface[0].network_ip}

    [kafka_nodes]
    az-kafka ansible_host=$${azurerm_network_interface.nics["kafka"].private_ip_address}
    gcp-kafka ansible_host=$${google_compute_instance.vms["kafka"].network_interface[0].network_ip}

    [etcd_nodes]
    az-etcd ansible_host=$${azurerm_network_interface.nics["etcd"].private_ip_address}
    gcp-etcd ansible_host=$${google_compute_instance.vms["etcd"].network_interface[0].network_ip}

    [storage_nodes]
    az-storage ansible_host=$${azurerm_network_interface.nics["storage"].private_ip_address}
    gcp-storage ansible_host=$${google_compute_instance.vms["storage"].network_interface[0].network_ip}

    [azure_nodes]
    az-app
    az-db
    az-kafka
    az-etcd
    az-storage

    [gcp_nodes]
    gcp-app
    gcp-db
    gcp-kafka
    gcp-etcd
    gcp-storage

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
    Host gcp-app
        HostName $${google_compute_instance.vms["app"].network_interface[0].access_config[0].nat_ip}
        User $${var.vm_admin_user}
        StrictHostKeyChecking accept-new
    Host gcp-*
        ProxyJump gcp-app
        User $${var.vm_admin_user}
        StrictHostKeyChecking accept-new
  EOT
}
"""

with open(f"{TF_DIR}/variables.tf", "w") as f: f.write(var_hcl)
with open(f"{TF_DIR}/azure.tf", "w") as f: f.write(azure_hcl)
with open(f"{TF_DIR}/gcp.tf", "w") as f: f.write(gcp_hcl)
with open(f"{TF_DIR}/inventory.tf", "w") as f: f.write(inventory_hcl)
