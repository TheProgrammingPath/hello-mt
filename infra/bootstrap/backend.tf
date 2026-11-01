terraform {
  backend "azurerm" {
    resource_group_name  = "rg-hello-mt-shared"
    storage_account_name = "sthellomtstate"
    container_name       = "tfstate"
    key                  = "bootstrap.tfstate"
    use_azuread_auth     = true
  }
}
