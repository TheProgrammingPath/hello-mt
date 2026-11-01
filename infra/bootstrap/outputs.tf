output "shared_resource_group_name" {
  description = "Name of the shared resource group."
  value       = azurerm_resource_group.shared.name
}

output "environment_resource_group_names" {
  description = "Resource group name for each environment."
  value       = { for env, rg in azurerm_resource_group.env : env => rg.name }
}

output "state_storage_account_name" {
  description = "Storage account that holds Terraform state."
  value       = azurerm_storage_account.state.name
}

output "acr_login_server" {
  description = "Login server of the shared container registry."
  value       = azurerm_container_registry.acr.login_server
}