// IAM and Service Account
resource "google_service_account" "k8s-master" {
  account_id   = "master-${var.cluster_name}"
  display_name = "K8s master service account"
}

resource "google_service_account_key" "k8s-master-key" {
  service_account_id = google_service_account.k8s-master.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

// Let master view resources and modify routes, firewalls, and disks 
resource "google_project_iam_member" "master-compute-viewer" {
  role   = "roles/compute.viewer"
  member = "serviceAccount:${google_service_account.k8s-master.email}"
}

resource "google_project_iam_member" "master-network" {
  role   = "roles/compute.networkAdmin"
  member = "serviceAccount:${google_service_account.k8s-master.email}"
}

resource "google_project_iam_member" "master-security" {
  role   = "roles/compute.securityAdmin"
  member = "serviceAccount:${google_service_account.k8s-master.email}"
}

resource "google_project_iam_member" "master-storage" {
  role   = "roles/compute.storageAdmin"
  member = "serviceAccount:${google_service_account.k8s-master.email}"
}

resource "google_project_iam_member" "master-instance" {
  role   = "roles/compute.instanceAdmin.v1"
  member = "serviceAccount:${google_service_account.k8s-master.email}"
}

resource "google_project_iam_member" "master-service-account-user" {
  role   = "roles/iam.serviceAccountUser"
  member = "serviceAccount:${google_service_account.k8s-master.email}"
}

// Master Instances
resource "google_compute_instance_template" "master" {
  name_prefix          = "master-${var.cluster_name}-"
  instance_description = "master k8s instance"
  machine_type         = var.master_instance_type
  can_ip_forward       = true

  disk {
    source_image = var.container_linux_image
    auto_delete  = true
    boot         = true
    disk_size_gb = "50"
  }

  network_interface {
    subnetwork = var.subnetwork_link
  }

  metadata = {
    user-data = var.master_user_data
  }

  service_account {
    email  = google_service_account.k8s-master.email
    scopes = ["cloud-platform"]
  }

  tags = concat(["master-${var.cluster_name}", "kubelet"], var.cluster_instance_tags)

  labels = {
    cluster = var.cluster_name
    name    = "${var.cluster_name}-master"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_pool" "masters-pool" {
  name = "masters-pool-${var.cluster_name}"
}

resource "google_compute_region_instance_group_manager" "masters" {
  name               = "masters-group-manager-${var.cluster_name}"
  base_instance_name = "master-${var.cluster_name}"
  region             = var.region
  target_size        = var.master_instance_count
  target_pools       = [google_compute_target_pool.masters-pool.self_link]

  update_policy {
    type           = "OPPORTUNISTIC"
    minimal_action = "REPLACE"
  }

  version {
    name              = "masters"
    instance_template = google_compute_instance_template.master.self_link
  }
}

// Load Balancer
resource "google_compute_forwarding_rule" "master-lb" {
  name                  = "master-lb-${var.cluster_name}"
  target                = google_compute_target_pool.masters-pool.self_link
  load_balancing_scheme = "EXTERNAL"
  ip_protocol           = "TCP"
  port_range            = "443"
}

// Dns
resource "google_dns_record_set" "master" {
  name = "lb.master.${var.dns_domain}."
  type = "A"
  ttl  = 30

  managed_zone = var.dns_zone

  rrdatas = [google_compute_forwarding_rule.master-lb.ip_address]
}

// Firewall Rules
resource "google_compute_firewall" "allow-masters-to-talk" {
  name    = "allow-masters-to-talk-${var.cluster_name}"
  network = var.network_link

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "ipip"
  }

  source_tags = ["master-${var.cluster_name}"]

  direction   = "INGRESS"
  target_tags = ["master-${var.cluster_name}"]
}

resource "google_compute_firewall" "allow-workers-to-masters" {
  name    = "allow-workers-to-masters-${var.cluster_name}"
  network = var.network_link

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "ipip"
  }

  source_tags = ["worker-${var.cluster_name}"]

  direction   = "INGRESS"
  target_tags = ["master-${var.cluster_name}"]
}

resource "google_compute_firewall" "allow-world-to-masters" {
  name    = "allow-world-to-masters-${var.cluster_name}"
  network = var.network_link

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]

  direction   = "INGRESS"
  target_tags = ["master-${var.cluster_name}"]
}
