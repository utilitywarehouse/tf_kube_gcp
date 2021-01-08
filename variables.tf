// Common
variable "container_linux_image" {
  description = "The container linux image to use. Default to the latest from the stable channel"
  default     = "projects/kinvolk-public/global/images/family/flatcar-stable"
}

variable "cluster_name" {
  description = "An identifier for the cluster"
}

variable "cluster_instance_tags" {
  description = "A list of tags for all instances in the cluster"
  type        = list(string)
}

variable "dns_zone" {
  description = "The dns zone to add new dns records"
}

variable "dns_domain" {
  description = "The dns domain used as a suffix on new dns records"
}

variable "region" {
  description = "The region that the cluster will reside"
}

variable "available_zones" {
  description = "A list of zones available under the project"
  type        = list(string)
}

variable "network_link" {
  description = "Main network where firewall rules will live"
}

variable "subnetwork_link" {
  description = "Subnet to create cluster instances"
}

// cfssl server
variable "cfssl_server_address" {
  description = "the address of the cfssl server"
}

variable "cfssl_machine_type" {
  default     = "g1-small"
  description = "The type of cfssl instance to launch."
}

variable "cfssl_data_volume_id" {
  default     = "cfssl_data"
  description = "The id to use when attaching cfssl data volume to instance (cannot contain dashes `-` to avoid confusion on the device name)"
}

variable "cfssl_user_data" {
  description = "The user data to provide to the cfssl server."
}

// etcd nodes
variable "etcd_instance_count" {
  description = "The number of etcd instances to launch."
}

variable "etcd_addresses" {
  description = "A list of ip adrresses for etcd instances."
  type        = list(string)
}

variable "etcd_machine_type" {
  default     = "n1-standard-1"
  description = "The type of etcd instances to launch."
}

variable "etcd_data_volume_size" {
  description = "The size (in GB) of the data volumes used in etcd nodes."
  default     = "5"
}

variable "etcd_user_data" {
  description = "The user data to provide to the etcd instances."
  type        = list(string)
}

// master nodes
variable "master_instance_count" {
  default     = "3"
  description = "The number of kubernetes master instances to launch."
}

variable "master_instance_type" {
  default     = "n1-standard-1"
  description = "The type of kubernetes master instances to launch."
}

variable "master_user_data" {
  description = "The user data to provide to the kube masters."
}

// worker nodes
variable "worker_instance_count" {
  default     = "3"
  description = "The number of kubernetes worker instances to launch."
}

variable "worker_instance_type" {
  default     = "n1-standard-1"
  description = "The type of kubernetes worker instances to launch."
}

variable "worker_user_data" {
  description = "The user data to provide to the kube masters."
}
