// IAM and Service Account
resource "google_service_account" "cfssl" {
  account_id   = "cfssl-${var.cluster_name}"
  display_name = "service account for cfssl instance"
}

// Volume
resource "google_compute_disk" "cfssl-data" {
  name = "cfssl-data-${var.cluster_name}"
  zone = var.available_zones[0]
  size = 5
  type = "pd-standard"

  // The value can only contain lowercase letters, numeric characters, underscores and dashes
  labels = {
    name      = "cfssl-${var.cluster_name}-data-vol-0"
    component = "${var.cluster_name}-cfssl"
    cluster   = var.cluster_name
  }
}

resource "random_string" "cfssl_suffix" {
  length  = 4
  special = false
  upper   = false

  keepers = {
    userdata = var.cfssl_user_data
  }
}

// reserve Ip address
resource "google_compute_address" "cfssl_server_address" {
  name         = "cfssl-server-address-0-${var.cluster_name}"
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork_link
  address      = var.cfssl_server_address
}

// Instance
resource "google_compute_instance" "cfssl" {
  name        = "cfssl-${var.cluster_name}-${random_string.cfssl_suffix.result}"
  description = "cfssl box"

  machine_type              = var.cfssl_machine_type
  zone                      = var.available_zones[0]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.container_linux_image
    }

    auto_delete = true
  }

  attached_disk {
    source      = google_compute_disk.cfssl-data.self_link
    mode        = "READ_WRITE"
    device_name = var.cfssl_data_volume_id
  }

  network_interface {
    subnetwork = var.subnetwork_link
    network_ip = google_compute_address.cfssl_server_address.address
  }

  tags = concat(["cfssl-${var.cluster_name}"], var.cluster_instance_tags)

  labels = {
    cluster = var.cluster_name
    name    = "${var.cluster_name}-cfssl"
  }

  metadata = {
    user-data = var.cfssl_user_data
  }

  service_account {
    email  = google_service_account.cfssl.email
    scopes = []
  }
}

// Firewall Rules
resource "google_compute_firewall" "allow-etcd-to-cfssl" {
  name    = "allow-etcd-to-cfssl-${var.cluster_name}"
  network = var.network_link

  allow {
    protocol = "tcp"
    ports    = ["8888"]
  }

  source_tags = ["etcd-${var.cluster_name}"]

  direction   = "INGRESS"
  target_tags = ["cfssl-${var.cluster_name}"]
}

resource "google_compute_firewall" "allow-masters-to-cfssl" {
  name    = "allow-masters-to-cfssl-${var.cluster_name}"
  network = var.network_link

  allow {
    protocol = "tcp"
    ports    = ["8888", "8889"]
  }

  source_tags = ["master-${var.cluster_name}"]

  direction   = "INGRESS"
  target_tags = ["cfssl-${var.cluster_name}"]
}

resource "google_compute_firewall" "allow-workers-to-cfssl" {
  name    = "allow-workers-to-cfssl-${var.cluster_name}"
  network = var.network_link

  // 8080 for fluent-bit exporter, 8888-9 for certs, 9100 for node exporter
  allow {
    protocol = "tcp"
    ports    = ["8080", "8888", "8889", "9100"]
  }

  source_tags = ["worker-${var.cluster_name}"]

  direction   = "INGRESS"
  target_tags = ["cfssl-${var.cluster_name}"]
}

// Dns
resource "google_dns_record_set" "cfssl" {
  name = "cfssl.${var.dns_domain}."
  type = "A"
  ttl  = 30

  managed_zone = var.dns_zone

  rrdatas = [google_compute_instance.cfssl.network_interface[0].network_ip]
}
