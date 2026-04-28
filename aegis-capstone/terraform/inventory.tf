
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
