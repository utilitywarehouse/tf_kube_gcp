// Volume
resource "google_compute_disk" "cfssl-data" {
  name = "cfssl-data-${var.cluster_name}"
  zone = "${var.available_zones[0]}"
  size = 5
  type = "pd-standard"

  // The value can only contain lowercase letters, numeric characters, underscores and dashes
  labels {
    name      = "cfssl-${var.cluster_name}-data-vol-${count.index}"
    component = "${var.cluster_name}-cfssl"
    cluster   = "${var.cluster_name}"
  }
}

// Instance
resource "google_compute_instance" "cfssl" {
  name        = "cfssl-${var.cluster_name}"
  description = "cfssl box"

  machine_type = "${var.cfssl_machine_type}"
  zone         = "${var.available_zones[0]}"

  boot_disk {
    initialize_params {
      image = "coreos-cloud/coreos-stable"
    }

    auto_delete = true
  }

  attached_disk {
    source      = "${google_compute_disk.cfssl-data.self_link}"
    mode        = "READ_WRITE"
    device_name = "${var.cfssl_data_volume_id}"
  }

  network_interface {
    subnetwork = "${var.subnetwork_link}"
    address    = "${var.cfssl_server_address}"
  }

  tags = ["${concat(list("cfssl-${var.cluster_name}"), var.cluster_instance_tags)}"]

  labels = {
    cluster = "${var.cluster_name}"
    name    = "${var.cluster_name}-cfssl"
  }

  metadata {
    user-data = "${var.cfssl_user_data}"
  }
}

// Firewall Rules
resource "google_compute_firewall" "allow-etcd-to-cfssl" {
  name    = "allow-etcd-to-cfssl-${var.cluster_name}"
  network = "${var.network_link}"

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
  network = "${var.network_link}"

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
  network = "${var.network_link}"

  // 8888-9 for certs, 9100 for node exporter
  allow {
    protocol = "tcp"
    ports    = ["8888", "8889", "9100"]
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

  managed_zone = "${var.dns_zone}"

  rrdatas = ["${google_compute_instance.cfssl.network_interface.0.address}"]
}
