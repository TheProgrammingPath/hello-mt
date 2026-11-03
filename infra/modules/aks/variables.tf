variable "name" {
  type        = string
  description = "Cluster name, e.g. aks-hello-mt-dev; also used as the DNS prefix."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that holds the cluster."
}

variable "kubernetes_version" {
  type        = string
  description = "Pinned Kubernetes minor version (from az aks get-versions), e.g. 1.36."
}

variable "subnet_id" {
  type        = string
  description = "ID of the snet-aks subnet for the nodes."
}

variable "node_vm_size" {
  type        = string
  description = "VM size of the system node pool."
}

variable "node_min_count" {
  type        = number
  description = "Cluster autoscaler minimum node count."
}

variable "node_max_count" {
  type        = number
  description = "Cluster autoscaler maximum node count."
}

variable "zones" {
  type        = list(string)
  description = "Availability zones for the node pool; empty for no zones (dev)."
  default     = []
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace that receives container logs (oms_agent)."
}

variable "acr_id" {
  type        = string
  description = "Container registry the kubelet identity may pull from (AcrPull)."
}

variable "cluster_admin_principal_ids" {
  type        = map(string)
  description = "Entra object IDs granted Azure Kubernetes Service RBAC Cluster Admin, keyed by a label."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource in this module."
}
