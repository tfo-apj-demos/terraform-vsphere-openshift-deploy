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

# --- Generate a Vault token for the agent to bootstrap and retrieve certificates
resource "vault_token" "this" {
  for_each  = toset(var.hostnames)
  no_parent = true
  period    = "2h"
  policies = [
    "generate_certificate"
  ]
}

#>>  NO LB REQUIRED
/* # --- Deploy Load Balancer
module "load_balancer" {
  source  = "app.terraform.io/tfo-apj-demos/load-balancer/nsxt"
  version = "0.0.3-beta"

  hosts = [for host in module.openshift_server : {
    "hostname" = host.virtual_machine_name
    "address"  = host.ip_address
  }]
  ports = [
    "4646"
  ]
  load_balancer_ip_address = nsxt_policy_ip_address_allocation.load_balancer.allocation_ip
  name                     = "openshift"
  lb_app_profile_type      = "TCP"
} */

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

# --- Create Boundary targets for the Vault nodes
module "boundary_target" {
  source  = "app.terraform.io/tfo-apj-demos/target/boundary"
  version = "1.0.13-alpha"

  hosts = [for host in module.openshift_server : {
    "hostname" = host.virtual_machine_name
    "address"  = host.ip_address
  }]

  services = [
    {
      name             = "ssh",
      type             = "ssh",
      port             = "22",
      credential_paths = [module.ssh_role.credential_path]
    }
  ]

  project_name    = "gcve_admins"
  host_catalog_id = "hcst_RACKlVym4Z"
  hostname_prefix = "ssh"

  credential_store_token = module.ssh_role.token
  vault_address          = var.vault_address
  #vault_ca_cert          = file("${path.root}/ca_cert_dir/ca_chain.pem")
}


# --- Add LB to DNS
module "load_balancer_dns" {
  source  = "app.terraform.io/tfo-apj-demos/domain-name-system-management/dns"
  version = "~> 1.0"

  a_records = [
    {
      name      = var.load_balancer_dns_name
      addresses = [nsxt_policy_ip_address_allocation.load_balancer.allocation_ip]
    }
  ]
}

# --- Add servers to DNS
module "openshift_server_dns" {
  source  = "app.terraform.io/tfo-apj-demos/domain-name-system-management/dns"
  version = "~> 1.0"

  a_records = [for host in module.openshift_server : {
    "name"      = host.virtual_machine_name
    "addresses" = [host.ip_address]
  }]
}
