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
output "github_client_ids" {
  description = "Client IDs of the GitHub OIDC identities (IDs, not secrets)."
  value       = { for k, id in azurerm_user_assigned_identity.gh : k => id.client_id }
}

output "tenant_id" {
  description = "Entra tenant ID."
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "Azure subscription ID."
  value       = data.azurerm_client_config.current.subscription_id
}