
variable "project_name" { default = "aegis-v4" }
variable "operator_ip" {}
variable "ssh_public_key_path" { default = "~/.ssh/id_ed25519.pub" }
variable "vm_admin_user" { default = "ansible_user" }
variable "azure_subscription_id" {}
variable "azure_location_1" { default = "australiaeast" }
variable "azure_location_2" { default = "australiasoutheast" }
variable "azure_location_3" { default = "southeastasia" }
variable "azure_vm_size" { default = "Standard_D2s_v5" }
variable "azure_image_id" {
  description = "Custom image ID for the VMs. If null, standard Ubuntu 22.04 is used."
  type        = string
  default     = null
}
