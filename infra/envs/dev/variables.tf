variable "environment" {
  type        = string
  description = "Environment name: dev or prod."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "initials" {
  type        = string
  description = "Owner initials used in resource names (2 to 4 lowercase letters)."

  validation {
    condition     = can(regex("^[a-z]{2,4}$", var.initials))
    error_message = "initials must be 2 to 4 lowercase letters."
  }
}

variable "owner" {
  type        = string
  description = "Value of the owner tag."
}

variable "expires_on" {
  type        = string
  description = "Value of the expires-on tag (YYYY-MM-DD)."
}

variable "vnet_address_space" {
  type        = string
  description = "VNet address space (/16)."
}

variable "log_daily_quota_gb" {
  type        = number
  description = "Log Analytics daily ingestion cap in GB."
}

variable "kubernetes_version" {
  type        = string
  description = "Pinned Kubernetes minor version."
}

variable "aks_node_vm_size" {
  type        = string
  description = "AKS node VM size."
}

variable "aks_node_min_count" {
  type        = number
  description = "AKS autoscaler minimum nodes."
}

variable "aks_node_max_count" {
  type        = number
  description = "AKS autoscaler maximum nodes."
}

variable "aks_zones" {
  type        = list(string)
  description = "Availability zones for the node pool (empty in dev)."
}

variable "aks_cluster_admin_principal_ids" {
  type        = map(string)
  description = "Entra object IDs that get AKS RBAC Cluster Admin (owner and the environment's GitHub identity)."
}