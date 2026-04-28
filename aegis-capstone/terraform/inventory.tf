
resource "local_file" "inventory" {
  filename = "../ansible/inventory/hosts.ini"
  content  = <<-EOT
    [app_nodes]
    az-app ansible_host=$${azurerm_public_ip.app.ip_address}
    gcp-app ansible_host=$${google_compute_instance.vms["app"].network_interface[0].access_config[0].nat_ip}

    [monitor_nodes]
    az-app
    gcp-app

    [db_nodes]
    az-db ansible_host=$${azurerm_network_interface.nics["db"].private_ip_address}
    gcp-db ansible_host=$${google_compute_instance.vms["db"].network_interface[0].network_ip}

    [kafka_nodes]
    az-kafka ansible_host=$${azurerm_network_interface.nics["kafka"].private_ip_address}
    gcp-kafka ansible_host=$${google_compute_instance.vms["kafka"].network_interface[0].network_ip}

    [storage_nodes]
    az-storage ansible_host=$${azurerm_network_interface.nics["storage"].private_ip_address}
    gcp-storage ansible_host=$${google_compute_instance.vms["storage"].network_interface[0].network_ip}

    [azure_nodes]
    az-app
    az-db
    az-kafka
    az-storage

    [gcp_nodes]
    gcp-app
    gcp-db
    gcp-kafka
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

# --- AZURE VARIABLES ---
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
      { name = "kafka_jbod1", dev = "/dev/sdd", fs = "xfs", mount = "/var/lib/kafka/data1" },
      { name = "etcd", dev = "/dev/sde", fs = "ext4", mount = "/var/lib/etcd" }
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

# --- GCP VARIABLES ---
resource "local_file" "hv_gcp_app" {
  filename = "../ansible/inventory/host_vars/gcp-app.yml"
  content  = yamlencode({
    aegis_cloud = "gcp",
    aegis_data_devices = [
      { name = "monitor", dev = "/dev/disk/by-id/google-monitor", fs = "xfs", mount = "/var/lib/victoria-metrics-data" }
    ],
    aegis_raid_devices = []
  })
}

resource "local_file" "hv_gcp_db" {
  filename = "../ansible/inventory/host_vars/gcp-db.yml"
  content  = yamlencode({
    aegis_cloud = "gcp",
    aegis_data_devices = [
      { name = "pgsql", dev = "/dev/disk/by-id/google-pgsql", fs = "ext4", mount = "/var/lib/postgresql" },
      { name = "mongo", dev = "/dev/disk/by-id/google-mongo", fs = "xfs", mount = "/var/lib/mongodb" },
      { name = "redis", dev = "/dev/disk/by-id/google-redis", fs = "ext4", mount = "/var/lib/redis" }
    ],
    aegis_raid_devices = []
  })
}

resource "local_file" "hv_gcp_kafka" {
  filename = "../ansible/inventory/host_vars/gcp-kafka.yml"
  content  = yamlencode({
    aegis_cloud = "gcp",
    aegis_data_devices = [
      { name = "kafka_jbod0", dev = "/dev/disk/by-id/google-jbod0", fs = "xfs", mount = "/var/lib/kafka/data0" },
      { name = "kafka_jbod1", dev = "/dev/disk/by-id/google-jbod1", fs = "xfs", mount = "/var/lib/kafka/data1" },
      { name = "etcd", dev = "/dev/disk/by-id/google-etcd", fs = "ext4", mount = "/var/lib/etcd" }
    ],
    aegis_raid_devices = []
  })
}

resource "local_file" "hv_gcp_storage" {
  filename = "../ansible/inventory/host_vars/gcp-storage.yml"
  content  = yamlencode({
    aegis_cloud = "gcp",
    aegis_data_devices = [
      { name = "backups", dev = "/dev/md0", fs = "xfs", mount = "/mnt/backups" }
    ],
    aegis_raid_devices = [
      "/dev/disk/by-id/google-raid0",
      "/dev/disk/by-id/google-raid1",
      "/dev/disk/by-id/google-raid2"
    ]
  })
}
