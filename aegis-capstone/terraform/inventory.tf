
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
