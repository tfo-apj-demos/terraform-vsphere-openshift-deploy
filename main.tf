locals {
  hostnames = [for v in range(var.cluster_size) : format("openshift-%s", v)]
}

# # --- Get latest RHEL image value from HCP Packer
# data "hcp_packer_artifact" "this" {
#   bucket_name  = "base-rhel-9"
#   channel_name = "latest"
#   platform     = "vsphere"
#   region       = "Datacenter"
# }

# # --- Retrieve IPs for use by the load balancer and Openshift virtual machines
# data "nsxt_policy_ip_pool" "this" {
#   display_name = "10 - gcve-foundations"
# }
# resource "nsxt_policy_ip_address_allocation" "this" {
#   for_each     = toset(var.hostnames)
#   display_name = each.value
#   pool_path    = data.nsxt_policy_ip_pool.this.path
# }

# resource "nsxt_policy_ip_address_allocation" "load_balancer" {
#   display_name = "openshift-load-balancer"
#   pool_path    = data.nsxt_policy_ip_pool.this.path
# }



data "vsphere_datacenter" "datacenter" {
  name = "Datacenter"
}

data "vsphere_datastore" "datastore" {
  name          = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = "cluster"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "network" {
  name          = "seg-general"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

# deploy shell vm and attach iso using the vsphere vm resource not the module
resource "vsphere_virtual_machine" "vm" {
  for_each = toset(var.hostnames)
  name             = each.value
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus         = 12
  memory           = 32768
  guest_id         = "otherLinux64Guest"
  folder = "Demo Workloads"
  scsi_type = "lsilogic-sas"
  enable_disk_uuid = true

  network_interface {
    network_id = data.vsphere_network.network.id
  }
  disk {
    label = "disk0"
    size  = 150
  }

  cdrom {
    datastore_id = data.vsphere_datastore.datastore.id
    path         = "ISO/b649ce88-11c8-4504-9c72-3f1729fbaa02-discovery.iso"
  }
}



# module "ssh_role" {
#   source  = "app.terraform.io/tfo-apj-demos/ssh-role/vault"
#   version = "0.0.4"

#   # insert required variables here
#   ssh_role_name = "${var.TFC_WORKSPACE_ID}-openshift_ssh_ca_signing"
# }

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

# # --- Add servers to DNS
# module "openshift_server_dns" {
#   source  = "app.terraform.io/tfo-apj-demos/domain-name-system-management/dns"
#   version = "~> 1.0"

#   a_records = [for host in module.openshift_server : {
#     "name"      = host.virtual_machine_name
#     "addresses" = [host.ip_address]
#   }]
# }
