variable "project_name" {
  description = "Project tag prefix used in resource names."
  type        = string
  default     = "aegis"
}

variable "operator_ip" {
  description = "Public IP (CIDR /32) of the operator workstation. Allowed to reach the Azure bastion on tcp/22."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the operator SSH public key (injected into all VMs as ansible_user)."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_admin_user" {
  description = "Linux admin user created on every VM. Must match Ansible inventory."
  type        = string
  default     = "ansible_user"
}

# ----- Azure -----
variable "azure_subscription_id" {
  description = "Target Azure subscription ID."
  type        = string
}

variable "azure_location" {
  description = "Azure region for the stateful tier (db) + app/bastion."
  type        = string
  default     = "westeurope"
}

variable "azure_vm_size" {
  description = "VM SKU for Azure compute."
  type        = string
  default     = "Standard_D2s_v5"
}

# ----- GCP -----
variable "gcp_project_id" {
  description = "GCP project ID."
  type        = string
}

variable "gcp_region" {
  description = "GCP region for kafka + monitor nodes."
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP zone within gcp_region."
  type        = string
  default     = "us-central1-a"
}

variable "gcp_machine_type" {
  description = "GCE machine type."
  type        = string
  default     = "e2-standard-2"
}

variable "gcp_expose_ssh_publicly" {
  description = "If true, GCP firewall allows SSH from operator_ip directly (skip bastion). Convenient for first provisioning; flip to false once WireGuard is up."
  type        = bool
  default     = true
}

# ----- Ansible inventory -----
variable "ansible_inventory_path" {
  description = "Where to render the generated inventory file."
  type        = string
  default     = "../ansible/inventory/hosts.ini"
}

variable "ansible_host_vars_dir" {
  description = "Where to render per-host disk/network facts consumed by Ansible roles."
  type        = string
  default     = "../ansible/inventory/host_vars"
}
