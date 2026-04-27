# =============================================================================
# GCP: kafka-node (KRaft, RAID5 on 3 PDs) + monitor-node (VictoriaMetrics)
# =============================================================================

locals {
  gcp_prefix = "${var.project_name}-gcp"

  # GCE attached PDs are exposed as /dev/disk/by-id/google-<device-name>.
  # We use stable by-id paths instead of /dev/sdX so attach order doesn't matter.
  gcp_kafka_disks = ["k0", "k1", "k2"] # → /dev/disk/by-id/google-k0..k2 (assembled into RAID 5)
}

# ---------- Networking ----------
resource "google_compute_network" "this" {
  name                            = "${local.gcp_prefix}-vpc"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
  routing_mode                    = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  name          = "${local.gcp_prefix}-subnet"
  ip_cidr_range = "10.20.1.0/24"
  region        = var.gcp_region
  network       = google_compute_network.this.id
}

# ---------- Firewall ----------
resource "google_compute_firewall" "internal" {
  name      = "${local.gcp_prefix}-fw-internal"
  network   = google_compute_network.this.name
  direction = "INGRESS"
  priority  = 100

  source_ranges = ["10.20.0.0/16", "10.10.0.0/16"] # gcp subnet + azure vnet (for future VPN/wireguard)
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow { protocol = "icmp" }
}

resource "google_compute_firewall" "ssh_from_operator" {
  count     = var.gcp_expose_ssh_publicly ? 1 : 0
  name      = "${local.gcp_prefix}-fw-ssh-operator"
  network   = google_compute_network.this.name
  direction = "INGRESS"
  priority  = 200

  source_ranges = [var.operator_ip]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "ssh_from_azure_bastion" {
  name      = "${local.gcp_prefix}-fw-ssh-bastion"
  network   = google_compute_network.this.name
  direction = "INGRESS"
  priority  = 210

  source_ranges = ["${azurerm_public_ip.bastion.ip_address}/32"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "monitor_ui" {
  name      = "${local.gcp_prefix}-fw-monitor"
  network   = google_compute_network.this.name
  direction = "INGRESS"
  priority  = 300

  source_ranges = [var.operator_ip]
  target_tags   = ["monitor"]
  allow {
    protocol = "tcp"
    ports    = ["3000", "8428"] # Grafana, VictoriaMetrics
  }
}

resource "google_compute_firewall" "wireguard" {
  name      = "${local.gcp_prefix}-fw-wireguard"
  network   = google_compute_network.this.name
  direction = "INGRESS"
  priority  = 220

  source_ranges = ["${azurerm_public_ip.bastion.ip_address}/32"]
  allow {
    protocol = "udp"
    ports    = ["51820"]
  }
}

# ---------- Persistent Disks ----------
resource "google_compute_disk" "kafka_data" {
  for_each = toset(local.gcp_kafka_disks)
  name     = "${local.gcp_prefix}-kafka-${each.key}"
  type     = "pd-ssd"
  zone     = var.gcp_zone
  size     = 16
}

resource "google_compute_disk" "monitor_data" {
  name = "${local.gcp_prefix}-monitor-data"
  type = "pd-ssd"
  zone = var.gcp_zone
  size = 32
}

# ---------- Instances ----------
resource "google_compute_instance" "kafka" {
  name         = "${local.gcp_prefix}-kafka"
  machine_type = var.gcp_machine_type
  zone         = var.gcp_zone
  tags         = ["kafka", "stateful"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  dynamic "attached_disk" {
    for_each = google_compute_disk.kafka_data
    content {
      source      = attached_disk.value.id
      device_name = attached_disk.key # exposes as /dev/disk/by-id/google-<key>
    }
  }

  network_interface {
    network    = google_compute_network.this.id
    subnetwork = google_compute_subnetwork.this.id

    dynamic "access_config" {
      for_each = var.gcp_expose_ssh_publicly ? [1] : []
      content {}
    }
  }

  metadata = {
    ssh-keys = "${var.vm_admin_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }
}

resource "google_compute_instance" "monitor" {
  name         = "${local.gcp_prefix}-monitor"
  machine_type = var.gcp_machine_type
  zone         = var.gcp_zone
  tags         = ["monitor"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.monitor_data.id
    device_name = "m0"
  }

  network_interface {
    network    = google_compute_network.this.id
    subnetwork = google_compute_subnetwork.this.id

    dynamic "access_config" {
      for_each = var.gcp_expose_ssh_publicly ? [1] : []
      content {}
    }
  }

  metadata = {
    ssh-keys = "${var.vm_admin_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }
}
