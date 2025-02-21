// IAM and Service Account
resource "google_service_account" "k8s-worker" {
  account_id   = "worker-${var.cluster_name}"
  display_name = "K8s worker service account"
}

resource "google_service_account_key" "k8s-worker-key" {
  service_account_id = google_service_account.k8s-worker.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

// Minimally privileged service account as documented here:
// https://cloud.google.com/kubernetes-engine/docs/how-to/protecting-cluster-metadata#service-account
resource "google_project_iam_member" "worker_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.k8s-worker.email}"
}

resource "google_project_iam_member" "worker_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.k8s-worker.email}"
}

resource "google_project_iam_member" "worker_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.k8s-worker.email}"
}

// Worker Instances
resource "google_compute_instance_template" "worker" {
  name_prefix          = "worker-${var.cluster_name}-"
  instance_description = "worker k8s instance"
  machine_type         = var.worker_instance_type
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
    user-data = var.worker_user_data
  }

  service_account {
    email = google_service_account.k8s-worker.email
    // The service accounts documentation explains that access scopes are the
    // legacy method of specifying permissions for your instance. To follow
    // best practices you should create a dedicated service account with the
    // minimum permissions the VM requires. To use a dedicated service account
    // this field should be configured as a list containing the cloud-platform
    // scope.
    // https://cloud.google.com/compute/docs/access/service-accounts#accesscopesiam
    scopes = ["cloud-platform"]
  }

  tags = concat(["worker-${var.cluster_name}", "kubelet"], var.cluster_instance_tags)

  labels = {
    cluster = var.cluster_name
    name    = "${var.cluster_name}-worker"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "workers" {
  name               = "workes-group-manager-${var.cluster_name}"
  base_instance_name = "worker-${var.cluster_name}"
  region             = var.region
  target_size        = var.worker_instance_count

  update_policy {
    type           = "OPPORTUNISTIC"
    minimal_action = "REPLACE"
  }

  version {
    name              = "workers"
    instance_template = google_compute_instance_template.worker.self_link
  }

  lifecycle {
    prevent_destroy = true
  }
}

// Firewall Rules
resource "google_compute_firewall" "allow-workers-to-talk" {
  name    = "allow-workers-to-talk-${var.cluster_name}"
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
  target_tags = ["worker-${var.cluster_name}"]
}

resource "google_compute_firewall" "allow-masters-to-workers" {
  name    = "allow-masters-to-workers-${var.cluster_name}"
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
  target_tags = ["worker-${var.cluster_name}"]
}
