# =============================================================================
# Azure: bastion (DMZ) + app-node (Nginx ingress) + db-node (Postgres/Mongo/Redis/etcd)
# =============================================================================

locals {
  az_prefix = "${var.project_name}-az"

  # Azure D-series device order: /dev/sda = OS, /dev/sdb = ephemeral, data LUNs start at /dev/sdc.
  # Keep this map in sync with azurerm_virtual_machine_data_disk_attachment.lun below.
  az_db_data_disks = {
    pgsql = { lun = 0, size_gb = 16, dev = "/dev/sdc" }
    mongo = { lun = 1, size_gb = 16, dev = "/dev/sdd" }
    redis = { lun = 2, size_gb = 16, dev = "/dev/sde" }
    etcd  = { lun = 3, size_gb = 16, dev = "/dev/sdf" }
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.az_prefix}"
  location = var.azure_location
  tags = {
    project = var.project_name
    tier    = "stateful+ingress"
  }
}

# ---------- Networking ----------
resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.az_prefix}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "dmz" {
  name                 = "snet-dmz"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "snet-private"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.10.2.0/24"]
}

# ---------- Network Security Groups ----------
resource "azurerm_network_security_group" "dmz" {
  name                = "nsg-${local.az_prefix}-dmz"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  security_rule {
    name                       = "Allow-SSH-Operator"
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
    name                       = "Allow-Wireguard"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_port_range     = "51820"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "private" {
  name                = "nsg-${local.az_prefix}-private"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  # Allow all intra-VNet traffic (default in Azure but expressed explicitly for auditability).
  security_rule {
    name                       = "Allow-VNet-East-West"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
    destination_port_range     = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  # Public HTTP/HTTPS into Nginx ingress on app-node (rule applies to NIC level via association).
  security_rule {
    name                       = "Allow-HTTP-Public"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dmz" {
  subnet_id                 = azurerm_subnet.dmz.id
  network_security_group_id = azurerm_network_security_group.dmz.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}

# ---------- Public IPs ----------
resource "azurerm_public_ip" "bastion" {
  name                = "pip-${local.az_prefix}-bastion"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "app" {
  name                = "pip-${local.az_prefix}-app"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ---------- NICs ----------
resource "azurerm_network_interface" "bastion" {
  name                = "nic-${local.az_prefix}-bastion"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.dmz.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_interface" "app" {
  name                = "nic-${local.az_prefix}-app"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app.id
  }
}

resource "azurerm_network_interface" "db" {
  name                = "nic-${local.az_prefix}-db"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ---------- VMs ----------
resource "azurerm_linux_virtual_machine" "bastion" {
  name                            = "${local.az_prefix}-bastion"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  size                            = "Standard_B1s"
  admin_username                  = var.vm_admin_user
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.bastion.id]

  admin_ssh_key {
    username   = var.vm_admin_user
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                            = "${local.az_prefix}-app"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  size                            = var.azure_vm_size
  admin_username                  = var.vm_admin_user
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app.id]

  admin_ssh_key {
    username   = var.vm_admin_user
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_managed_disk" "app_data" {
  name                 = "disk-${local.az_prefix}-app-data"
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
}

resource "azurerm_virtual_machine_data_disk_attachment" "app_data" {
  managed_disk_id    = azurerm_managed_disk.app_data.id
  virtual_machine_id = azurerm_linux_virtual_machine.app.id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_linux_virtual_machine" "db" {
  name                            = "${local.az_prefix}-db"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  size                            = var.azure_vm_size
  admin_username                  = var.vm_admin_user
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.db.id]

  admin_ssh_key {
    username   = var.vm_admin_user
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_managed_disk" "db_data" {
  for_each             = local.az_db_data_disks
  name                 = "disk-${local.az_prefix}-db-${each.key}"
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = each.value.size_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "db_data" {
  for_each           = local.az_db_data_disks
  managed_disk_id    = azurerm_managed_disk.db_data[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.db.id
  lun                = each.value.lun
  caching            = "ReadWrite"
}
