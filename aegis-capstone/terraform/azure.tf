
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

resource "azurerm_virtual_network_peering" "p23" {
  name                         = "p23"
  resource_group_name          = azurerm_resource_group.r2.name
  virtual_network_name         = azurerm_virtual_network.v2.name
  remote_virtual_network_id    = azurerm_virtual_network.v3.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "p32" {
  name                         = "p32"
  resource_group_name          = azurerm_resource_group.r3.name
  virtual_network_name         = azurerm_virtual_network.v3.name
  remote_virtual_network_id    = azurerm_virtual_network.v2.id
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
  name                = "pip-app-new"
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
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_port_range     = "22"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "grafana"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_port_range     = "3000"
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
data "azurerm_shared_image_version" "latest" {
  name                = "latest"
  image_name          = "aegis-ubuntu-base"
  gallery_name        = "aegis_gallery"
  resource_group_name = azurerm_resource_group.r1.name
}

resource "azurerm_linux_virtual_machine" "vms" {
  for_each = local.az_vms

  name                = "az-${each.key}"
  resource_group_name = each.value.rg.name
  location            = each.value.rg.location
  size                = var.azure_vm_size
  admin_username      = var.vm_admin_user
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

  source_image_id = data.azurerm_shared_image_version.latest.id

  # source_image_reference block is removed as we always use the gallery image now.
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
