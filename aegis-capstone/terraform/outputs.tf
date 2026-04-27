output "azure_bastion_ip" {
  description = "Public IP of the Azure bastion (entrypoint)."
  value       = azurerm_public_ip.bastion.ip_address
}

output "azure_app_ip" {
  description = "Public IP of the Azure app/ingress node."
  value       = azurerm_public_ip.app.ip_address
}

output "azure_db_private_ip" {
  description = "Private VNet IP of the db node (no public access)."
  value       = azurerm_network_interface.db.private_ip_address
}

output "gcp_kafka_ip" {
  description = "Reachable IP of the GCP kafka node (public if gcp_expose_ssh_publicly, else private)."
  value       = local.gcp_kafka_ip
}

output "gcp_monitor_ip" {
  description = "Reachable IP of the GCP monitor node."
  value       = local.gcp_monitor_ip
}

output "next_steps" {
  description = "What to do after apply."
  value       = <<-EOT
    1. Inventory rendered to ${var.ansible_inventory_path}
    2. Per-host disk facts in ${var.ansible_host_vars_dir}/
    3. Optional: cp terraform/.generated/ssh_config ~/.ssh/aegis_config && \
       echo 'Include ~/.ssh/aegis_config' >> ~/.ssh/config
    4. Run: cd ../ansible && ansible-playbook site.yml
  EOT
}
