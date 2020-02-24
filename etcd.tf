// IAM and Service Account
resource "google_service_account" "etcd" {
  account_id   = "etcd-${var.cluster_name}"
  display_name = "service account for etcd instances"
}

// Volumes
resource "google_compute_disk" "etcd-data" {
  count = var.etcd_instance_count
  name  = "etcd-data-${count.index}-${var.cluster_name}"
  zone  = var.available_zones[count.index]
  size  = var.etcd_data_volume_size
  type  = "pd-ssd"

  // The value can only contain lowercase letters, numeric characters, underscores and dashes
  labels = {
    name      = "etcd-${var.cluster_name}-data-vol-${count.index}"
    component = "${var.cluster_name}-etcd"
    cluster   = var.cluster_name
  }

  lifecycle {
    ignore_changes = [snapshot]
  }
}

resource "null_resource" "etcd_data_volume_ids" {
  count = var.etcd_instance_count

  triggers = {
    volume_id = "etcd_data_${count.index}"
  }
}

resource "random_string" "r" {
  count   = var.etcd_instance_count
  length  = 4
  special = false
  upper   = false

  keepers = {
    userdata = var.etcd_user_data[count.index]
  }
}

// reserve Ip addresses
resource "google_compute_address" "etcd_addresses" {
  count        = var.etcd_instance_count
  name         = "etcd-address-${count.index}-${var.cluster_name}"
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork_link
  address      = var.etcd_addresses[count.index]
}

// Instances
resource "google_compute_instance" "etcd" {
  count       = var.etcd_instance_count
  name        = "etcd-${count.index}-${var.cluster_name}-${random_string.r[count.index].result}"
  description = "etcd cluster member"

  machine_type              = var.etcd_machine_type
  zone                      = var.available_zones[count.index]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.container_linux_image
    }

    auto_delete = true
  }

  attached_disk {
    source      = google_compute_disk.etcd-data[count.index].self_link
    mode        = "READ_WRITE"
    device_name = null_resource.etcd_data_volume_ids.*.triggers.volume_id[count.index]
  }

  network_interface {
    subnetwork = var.subnetwork_link
    network_ip = google_compute_address.etcd_addresses[count.index].address
  }

  tags = concat(["etcd-${var.cluster_name}"], var.cluster_instance_tags)

  labels = {
    cluster = var.cluster_name
    name    = "${var.cluster_name}-etcd"
  }

  metadata = {
    user-data = var.etcd_user_data[count.index]
  }

  service_account {
    email  = google_service_account.etcd.email
    scopes = []
  }
}

// Firewall Rules
resource "google_compute_firewall" "allow-etcds-to-talk" {
  name    = "allow-etcds-to-talk-${var.cluster_name}"
  network = var.network_link

  allow {
    protocol = "tcp"
    ports    = ["2379", "2380"]
  }

  source_tags = ["etcd-${var.cluster_name}"]

  direction   = "INGRESS"
  target_tags = ["etcd-${var.cluster_name}"]
}

resource "google_compute_firewall" "allow-masters-to-etcds" {
  name    = "allow-masters-to-etcds-${var.cluster_name}"
  network = var.network_link

  allow {
    protocol = "tcp"
    ports    = ["2379", "2380"]
  }

  source_tags = ["master-${var.cluster_name}"]

  direction   = "INGRESS"
  target_tags = ["etcd-${var.cluster_name}"]
}

resource "google_compute_firewall" "allow-workerss-to-etcds" {
  name    = "allow-workers-to-etcds-${var.cluster_name}"
  network = var.network_link

  // Node exporter and metrics
  allow {
    protocol = "tcp"
    ports    = ["9100", "9378"]
  }

  source_tags = ["worker-${var.cluster_name}"]

  direction   = "INGRESS"
  target_tags = ["etcd-${var.cluster_name}"]
}

// dns
resource "google_dns_record_set" "etcd-by-instance" {
  count = var.etcd_instance_count
  name  = "${count.index}.etcd.${var.dns_domain}."
  type  = "A"
  ttl   = 30

  managed_zone = var.dns_zone

  rrdatas = [google_compute_instance.etcd.*.network_interface.0.network_ip[count.index]]
}

resource "google_dns_record_set" "etcd-all" {
  name = "etcd.${var.dns_domain}."
  type = "A"
  ttl  = 30

  managed_zone = var.dns_zone

  rrdatas = google_compute_instance.etcd.*.network_interface.0.network_ip
}
