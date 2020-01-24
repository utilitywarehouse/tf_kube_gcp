output "cfssl_data_volumeid" {
  value = var.cfssl_data_volume_id
}

output "etcd_data_volumeids" {
  value = null_resource.etcd_data_volume_ids.*.triggers.volume_id
}

output "master_address" {
  value = google_dns_record_set.master.name
}
