#--- Boundary connection variables
variable "boundary_address" {
  type    = string
  default = "https://8b596635-91df-45a3-8455-1ecbf5e8c43e.boundary.hashicorp.cloud"
}

# variable "service_account_authmethod_id" {
#   type = string
# }

# variable "service_account_name" {
#   type = string
# }

# variable "service_account_password" {
#   type = string
# }

#--- Openshift application variables
variable "cluster_size" {
  description = "The number of nodes in the cluster."
  type        = number
  default     = 8
}

variable "hostnames" {
  type    = list(string)
  default = ["openshift-01", "openshift-02", "openshift-03", "openshift-04", "openshift-05", "openshift-06", "openshift-07", "openshift-08"]
}


/* variable "load_balancer_dns_name" {
  type = string
} */

variable "TFC_WORKSPACE_ID" {}

variable "vault_address" {
  description = "Vault address for Boundary credential store configuration."
  default     = "https://vault.hashicorp.local:8200"
}