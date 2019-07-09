output "cfssl_data_volumeid" {
  value = var.cfssl_data_volume_id
}

output "etcd_data_volumeids" {
  value = null_resource.etcd_data_volume_ids.*.triggers.volume_id
}

output "master_address" {
  value = google_dns_record_set.master.name
}

output "masters_group" {
  value = google_compute_region_instance_group_manager.masters.instance_group
}

output "masters_pool" {
  value = google_compute_target_pool.masters-pool.self_link
}

output "workers_group" {
  value = google_compute_region_instance_group_manager.workers.instance_group
}

output "workers_pool" {
  value = google_compute_target_pool.workers-pool.self_link
}

output "worker_public_http_port_name" {
  value = "public-http"
}

output "worker_public_https_port_name" {
  value = "public-https"
}
