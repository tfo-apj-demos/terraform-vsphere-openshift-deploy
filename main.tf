locals {
  hostnames = [for v in range(var.cluster_size) : format("openshift-%s", v)]
}

# --- Get latest RHEL image value from HCP Packer
data "hcp_packer_artifact" "this" {
  bucket_name  = "base-rhel-9"
  channel_name = "latest"
  platform     = "vsphere"
  region       = "Datacenter"
}

# --- Retrieve IPs for use by the load balancer and Openshift virtual machines
data "nsxt_policy_ip_pool" "this" {
  display_name = "10 - gcve-foundations"
}
resource "nsxt_policy_ip_address_allocation" "this" {
  for_each     = toset(var.hostnames)
  display_name = each.value
  pool_path    = data.nsxt_policy_ip_pool.this.path
}

resource "nsxt_policy_ip_address_allocation" "load_balancer" {
  display_name = "openshift-load-balancer"
  pool_path    = data.nsxt_policy_ip_pool.this.path
}


# --- Deploy a cluster of Openshift servers
module "openshift_server" {
  for_each = toset(var.hostnames)
  source   = "app.terraform.io/tfo-apj-demos/virtual-machine/vsphere"
  version  = "~> 1.3"

  num_cpus          = 12
  memory            = 32768
  hostname          = each.value
  datacenter        = "Datacenter"
  cluster           = "cluster"
  primary_datastore = "vsanDatastore"
  folder_path       = "Demo Workloads"
  networks = {
    "seg-general" : "${nsxt_policy_ip_address_allocation.this[each.value].allocation_ip}/22"
  }
  dns_server_list = [
    "172.21.15.150",
    "10.10.0.8"
  ]
  gateway         = "172.21.12.1"
  dns_suffix_list = ["hashicorp.local"]

  template = data.hcp_packer_artifact.this.external_identifier
  tags = {
    "application" = "openshift-server"
  }
}

module "ssh_role" {
  source  = "app.terraform.io/tfo-apj-demos/ssh-role/vault"
  version = "0.0.4"

  # insert required variables here
  ssh_role_name = "${var.TFC_WORKSPACE_ID}-openshift_ssh_ca_signing"
}

# --- Add LB to DNS <<<< TO REMOVE THIS
# module "load_balancer_dns" {
#   source  = "app.terraform.io/tfo-apj-demos/domain-name-system-management/dns"
#   version = "~> 1.0"

#   a_records = [
#     {
#       name      = var.load_balancer_dns_name
#       addresses = [nsxt_policy_ip_address_allocation.load_balancer.allocation_ip]
#     }
#   ]
# }

# --- Add servers to DNS
module "openshift_server_dns" {
  source  = "app.terraform.io/tfo-apj-demos/domain-name-system-management/dns"
  version = "~> 1.0"

  a_records = [for host in module.openshift_server : {
    "name"      = host.virtual_machine_name
    "addresses" = [host.ip_address]
  }]
}
