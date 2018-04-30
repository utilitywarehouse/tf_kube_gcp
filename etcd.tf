// Volumes
resource "google_compute_disk" "etcd-data" {
  count = "${length(var.available_zones)}"
  name  = "etcd-data-${count.index}-${var.cluster_name}"
  zone  = "${var.available_zones[count.index]}"
  size  = "${var.etcd_data_volume_size}"
  type  = "pd-standard"

  // The value can only contain lowercase letters, numeric characters, underscores and dashes
  labels {
    name      = "etcd-${var.cluster_name}-data-vol-${count.index}"
    component = "${var.cluster_name}-etcd"
    cluster   = "${var.cluster_name}"
  }
}

resource "null_resource" "etcd_data_volume_ids" {
  count = "${length(var.available_zones)}"

  triggers {
    volume_id = "etcd_data_${count.index}"
  }
}

// Instances
resource "google_compute_instance" "etcd" {
  count       = "${length(var.available_zones)}"
  name        = "etcd-${count.index}-${var.cluster_name}"
  description = "etcd cluster member"

  machine_type = "${var.etcd_machine_type}"
  zone         = "${var.available_zones[count.index]}"

  boot_disk {
    initialize_params {
      image = "coreos-cloud/coreos-stable"
    }

    auto_delete = true
  }

  attached_disk {
    source      = "${google_compute_disk.etcd-data.*.self_link[count.index]}"
    mode        = "READ_WRITE"
    device_name = "${null_resource.etcd_data_volume_ids.*.triggers.volume_id[count.index]}"
  }

  network_interface {
    subnetwork = "${var.subnetwork_link}"
    address    = "${var.etcd_addresses[count.index]}"
  }

  tags = ["${concat(list("etcd-${var.cluster_name}"), var.cluster_instance_tags)}"]

  labels = {
    cluster = "${var.cluster_name}"
    name    = "${var.cluster_name}-etcd"
  }

  metadata {
    user-data = "${var.etcd_user_data[count.index]}"
  }
}

// Firewall Rules
resource "google_compute_firewall" "allow-etcds-to-talk" {
  name    = "allow-etcds-to-talk-${var.cluster_name}"
  network = "${var.network_link}"

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
  network = "${var.network_link}"

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
  network = "${var.network_link}"

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
  count = "${length(var.available_zones)}"
  name  = "${count.index}.etcd.${var.dns_domain}."
  type  = "A"
  ttl   = 30

  managed_zone = "${var.dns_zone}"

  rrdatas = ["${google_compute_instance.etcd.*.network_interface.0.address[count.index]}"]
}

resource "google_dns_record_set" "etcd-all" {
  name = "etcd.${var.dns_domain}."
  type = "A"
  ttl  = 30

  managed_zone = "${var.dns_zone}"

  rrdatas = ["${google_compute_instance.etcd.*.network_interface.0.address}"]
}
