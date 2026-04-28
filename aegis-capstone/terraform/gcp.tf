
provider "google" {
  project = var.gcp_project_id
}

resource "google_compute_network" "vpc" {
  name                    = "gcp-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "sub1" {
  name          = "gcp-sub1"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.20.1.0/24"
  region        = var.gcp_region_1
}

resource "google_compute_subnetwork" "sub2" {
  name          = "gcp-sub2"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.21.1.0/24"
  region        = var.gcp_region_2
}

resource "google_compute_firewall" "ssh" {
  name          = "gcp-fw-ssh"
  network       = google_compute_network.vpc.id
  source_ranges = [var.operator_ip]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "internal" {
  name          = "gcp-fw-internal"
  network       = google_compute_network.vpc.id
  source_ranges = ["10.0.0.0/8"]
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

locals {
  gcp_vms = {
    app     = { zone = var.gcp_zone_1, sub = google_compute_subnetwork.sub1.id, pip = true, disks = { monitor = 16 } }
    db      = { zone = var.gcp_zone_1, sub = google_compute_subnetwork.sub1.id, pip = false, disks = { pgsql = 16, mongo = 16, redis = 16 } }
    kafka   = { zone = var.gcp_zone_2, sub = google_compute_subnetwork.sub2.id, pip = false, disks = { jbod0 = 16, jbod1 = 16 } }
    etcd    = { zone = var.gcp_zone_2, sub = google_compute_subnetwork.sub2.id, pip = false, disks = { etcd = 16 } }
    storage = { zone = var.gcp_zone_2, sub = google_compute_subnetwork.sub2.id, pip = false, disks = { raid0 = 16, raid1 = 16, raid2 = 16 } }
  }
  gcp_disks_flat = flatten([
    for vm_k, vm_v in local.gcp_vms : [
      for d_k, d_v in vm_v.disks : {
        vm   = vm_k
        disk = d_k
        size = d_v
        zone = vm_v.zone
      }
    ]
  ])
}

resource "google_compute_disk" "disks" {
  for_each = { for d in local.gcp_disks_flat : "${d.vm}-${d.disk}" => d }
  name     = "gcp-${each.key}"
  type     = "pd-ssd"
  zone     = each.value.zone
  size     = each.value.size
}

resource "google_compute_instance" "vms" {
  for_each     = local.gcp_vms
  name         = "gcp-${each.key}"
  machine_type = var.gcp_machine_type
  zone         = each.value.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = each.value.sub
    dynamic "access_config" {
      for_each = each.value.pip ? [1] : []
      content {}
    }
  }

  dynamic "attached_disk" {
    for_each = each.value.disks
    content {
      source      = google_compute_disk.disks["${each.key}-${attached_disk.key}"].id
      device_name = attached_disk.key
    }
  }

  metadata = {
    ssh-keys = "${var.vm_admin_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }
}
