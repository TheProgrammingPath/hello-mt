# P3.4: one registry shared by dev and prod; images are promoted by SHA.
# Admin user disabled: pushes use Entra ID, AKS pulls with a managed identity.
resource "azurerm_container_registry" "acr" {
  name                = "cr${local.app}${var.initials}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = merge(local.base_tags, { env = "shared" })
}
