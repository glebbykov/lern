packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

variable "subscription_id" {
  type    = string
  default = env("ARM_SUBSCRIPTION_ID")
}

variable "client_id" {
  type    = string
  default = env("ARM_CLIENT_ID")
}

variable "client_secret" {
  type    = string
  default = env("ARM_CLIENT_SECRET")
}

variable "tenant_id" {
  type    = string
  default = env("ARM_TENANT_ID")
}

source "azure-arm" "ubuntu" {
  # Auth: либо service principal через ARM_CLIENT_ID/ARM_CLIENT_SECRET/ARM_TENANT_ID,
  # либо `az login`-идентичность через use_azure_cli_auth (требует az CLI на хосте).
  use_azure_cli_auth = var.client_id == "" ? true : false

  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = "aegis-v4-az-r1"
    gallery_name         = "aegis_gallery"
    image_name           = "aegis-ubuntu-base"
    image_version        = "1.0.{{timestamp}}"
    replication_regions  = ["australiaeast", "australiasoutheast", "southeastasia"]
  }

  managed_image_name                = "aegis-base-{{timestamp}}"
  managed_image_resource_group_name = "aegis-v4-az-r1"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  azure_tags = {
    project = "aegis"
    role    = "base"
  }

  vm_size                           = "Standard_D2s_v5"
  location                          = "southeastasia"
}

build {
  sources = ["source.azure-arm.ubuntu"]

  provisioner "shell" {
    inline = [
      "sleep 30",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates gnupg lsb-release",
      "sudo mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y lvm2 xfsprogs mdadm wireguard auditd ufw curl git openjdk-17-jre-headless nginx docker-ce docker-ce-cli containerd.io docker-compose-plugin",
      "# Node Exporter",
      "curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz",
      "tar xvf node_exporter-1.7.0.linux-amd64.tar.gz",
      "sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/",
      "rm -rf node_exporter-1.7.0.linux-amd64*",
      "sudo /usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
  }
}
