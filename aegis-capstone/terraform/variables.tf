
variable "project_name" { default = "aegis" }
variable "operator_ip" {}
variable "ssh_public_key_path" { default = "~/.ssh/id_ed25519.pub" }
variable "vm_admin_user" { default = "ansible_user" }

variable "azure_subscription_id" {}
variable "azure_location_1" { default = "australiaeast" }
variable "azure_location_2" { default = "australiasoutheast" }
variable "azure_vm_size" { default = "Standard_D2s_v5" }

variable "gcp_project_id" {}
variable "gcp_region_1" { default = "us-central1" }
variable "gcp_zone_1" { default = "us-central1-a" }
variable "gcp_region_2" { default = "us-west1" }
variable "gcp_zone_2" { default = "us-west1-c" }
variable "gcp_machine_type" { default = "e2-standard-2" }
