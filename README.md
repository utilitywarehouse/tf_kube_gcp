# tf_kube_gcp

This terraform module creates a kubernetes cluster in GCP. It's designed to synergise well with [tf_kube_ignition](https://github.com/utilitywarehouse/tf_kube_ignition).

## Input Variables

The input variables are documented in their description and it's best to refer to [variables.tf](variables.tf)

## Ouputs

- `master_address` - the endpoint on which the kubernetes api is made available
- `cfssl_data_volumeid`- id of cfssl persistent volume
- `etcd_data_volumeids`- list of ids of etcd persistent volumes
- `masters_group` - group VM management address for masters
- `masters_pool` - target pool address of the masters
- `workers_group` - group VM management address for workers
- `workers_pool` - target pool address of the workers
- `worker_public_http_port_name` - address that workers will accept public http protocol requests
- `worker_public_https_port_name` - address that workers will accept public https protocol requests

## Usage

Below is an example of how you might use this terraform module:

```hcl
module "cluster" {
  source                = "github.com/utilitywarehouse/tf_kube_gcp"
  cluster_name          = "k8s"
  cluster_instance_tags = ["k8s-europe-west-2", "nat-gw"]
  dns_zone              = "${var.project_dns_zone}"
  dns_domain            = "k8s.${var.dns_zone_name}"
  region                = "europe-west-2"
  available_zones       = "[europe-west-2a, europe-west-2b, europe-west-2c]"
  network_link          = "${data.terraform_remote_state.core.main_vpc_link}"
  subnetwork_link       = "${google_compute_subnetwork.k8s.self_link}"
  cfssl_server_address  = "${var.cfssl_instance_address}"
  cfssl_machine_type    = "n1-standard-2"
  cfssl_user_data       = "${module.ignition.cfssl}"
  etcd_addresses        = "${var.etcd_instance_addresses}"
  etcd_instance_count   = "${var.etcd_instance_count}"
  etcd_machine_type     = "n1-standard-2"
  etcd_data_volume_size = "50"
  etcd_user_data        = "${module.ignition.etcd}"
  master_instance_type  = "n1-standard-2"
  master_instance_count = "3"
  master_user_data      = "${module.ignition.master}"
  worker_instance_type  = "n1-standard-2"
  worker_instance_count = "3"
  worker_user_data      = "${module.ignition.worker}"
}
```
