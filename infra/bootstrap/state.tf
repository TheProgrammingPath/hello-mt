data "azurerm_client_config" "current" {}

# P3.3: remote state storage. Entra ID only (no keys), TLS 1.2,
# versioning and soft delete, and protected from accidental destroy.
resource "azurerm_storage_account" "state" {
  name                = "st${local.app}${var.initials}state"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = merge(local.base_tags, { env = "shared" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# Lets the person running Terraform read and write state blobs over Entra ID.
resource "azurerm_role_assignment" "me_state_blob" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
