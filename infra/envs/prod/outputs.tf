output "resource_group_name" {
  description = "Resource group of this environment."
  value       = data.azurerm_resource_group.env.name
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace of this environment."
  value       = module.monitoring.workspace_name
}

output "cluster_name" {
  description = "AKS cluster name (used by scripts/deploy.sh and CD)."
  value       = module.aks.cluster_name
}

output "node_resource_group" {
  description = "AKS-managed node resource group."
  value       = module.aks.node_resource_group
}