provider "azurerm" {
  features {}

  # Use Entra ID (not storage account keys) for blob data operations.
  # Required because the state account disables shared key access (P3.3).
  storage_use_azuread = true
}
