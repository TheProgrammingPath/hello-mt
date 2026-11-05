output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "aks_subnet_id" {
  description = "ID of the snet-aks subnet."
  value       = azurerm_subnet.aks.id
}
