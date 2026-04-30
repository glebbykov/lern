
resource "local_file" "inventory" {
  filename = "../ansible/inventory/hosts.ini"
  content  = <<-EOT
    [app_nodes]
    az-app ansible_host=${azurerm_public_ip.app.ip_address}

    [monitor_nodes]
    az-app

    [db_nodes]
    az-db ansible_host=${azurerm_network_interface.nics["db"].private_ip_address}

    [kafka_nodes]
    az-kafka ansible_host=${azurerm_network_interface.nics["kafka"].private_ip_address}

    [etcd_nodes]
    az-etcd ansible_host=${azurerm_network_interface.nics["etcd"].private_ip_address}

    [storage_nodes]
    az-storage ansible_host=${azurerm_network_interface.nics["storage"].private_ip_address}

    [azure_nodes]
    az-app
    az-db
    az-kafka
    az-etcd
    az-storage

    [stateful:children]
    db_nodes
    kafka_nodes
    etcd_nodes

    [k8s_future:children]
    app_nodes

    [runtime_hosts:children]
    app_nodes

    [app_nodes:vars]
    ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null'

    [private_nodes:children]
    db_nodes
    kafka_nodes
    etcd_nodes
    storage_nodes

    [private_nodes:vars]
    ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null ${var.vm_admin_user}@${azurerm_public_ip.app.ip_address}"'

    [all:vars]
    ansible_user=${var.vm_admin_user}
    ansible_ssh_private_key_file=~/.ssh/id_ed25519
    aegis_immutable_base=true
  EOT
}

resource "local_file" "ssh_config" {
  filename        = ".generated/ssh_config"
  file_permission = "0600"
  content         = <<-EOT
    Host az-app
        HostName ${azurerm_public_ip.app.ip_address}
        User ${var.vm_admin_user}
        IdentityFile ~/.ssh/id_ed25519
        StrictHostKeyChecking accept-new
        UserKnownHostsFile /dev/null
    Host az-*
        ProxyJump az-app
        User ${var.vm_admin_user}
        IdentityFile ~/.ssh/id_ed25519
        StrictHostKeyChecking accept-new
        UserKnownHostsFile /dev/null
  EOT
}

resource "local_file" "hv_az_app" {
  filename = "../ansible/inventory/host_vars/az-app.yml"
  content  = yamlencode({
    aegis_cloud = "azure",
    aegis_data_devices = [
      { name = "monitor", lun = 0, fs = "xfs", mount = "/var/lib/victoria-metrics-data" }
    ],
    aegis_raid_luns = []
  })
}

resource "local_file" "hv_az_db" {
  filename = "../ansible/inventory/host_vars/az-db.yml"
  content  = yamlencode({
    aegis_cloud = "azure",
    aegis_data_devices = [
      { name = "pgsql", lun = 0, fs = "ext4", mount = "/var/lib/postgresql" },
      { name = "mongo", lun = 1, fs = "xfs", mount = "/var/lib/mongodb" },
      { name = "redis", lun = 2, fs = "ext4", mount = "/var/lib/redis" }
    ],
    aegis_raid_luns = []
  })
}

resource "local_file" "hv_az_kafka" {
  filename = "../ansible/inventory/host_vars/az-kafka.yml"
  content  = yamlencode({
    aegis_cloud = "azure",
    aegis_data_devices = [
      { name = "kafka_jbod0", lun = 0, fs = "xfs", mount = "/var/lib/kafka/data0" },
      { name = "kafka_jbod1", lun = 1, fs = "xfs", mount = "/var/lib/kafka/data1" }
    ],
    aegis_raid_luns = []
  })
}

resource "local_file" "hv_az_etcd" {
  filename = "../ansible/inventory/host_vars/az-etcd.yml"
  content  = yamlencode({
    aegis_cloud = "azure",
    aegis_data_devices = [
      { name = "etcd", lun = 0, fs = "ext4", mount = "/var/lib/etcd" }
    ],
    aegis_raid_luns = []
  })
}

resource "local_file" "hv_az_storage" {
  filename = "../ansible/inventory/host_vars/az-storage.yml"
  content  = yamlencode({
    aegis_cloud = "azure",
    aegis_data_devices = [
      { name = "backups", dev = "/dev/md0", fs = "xfs", mount = "/mnt/backups" }
    ],
    aegis_raid_luns = [0, 1, 2]
  })
}
