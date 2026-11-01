# P3.6: GitHub Actions identities. GitHub reaches Azure with short-lived
# OIDC tokens; each federated credential trusts one exact subject.

resource "azurerm_user_assigned_identity" "gh" {
  for_each = toset(["plan", "dev", "prod"])

  name                = "id-${local.app}-gh-${each.key}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tags                = merge(local.base_tags, { env = each.key == "plan" ? "shared" : each.key })
}

locals {
  federated_subjects = {
    "plan-pull-request" = { identity = "plan", subject = "repo:${var.github_repository}:pull_request" }
    "plan-main"         = { identity = "plan", subject = "repo:${var.github_repository}:ref:refs/heads/main" }
    "dev-environment"   = { identity = "dev", subject = "repo:${var.github_repository}:environment:dev" }
    "prod-environment"  = { identity = "prod", subject = "repo:${var.github_repository}:environment:prod" }
  }

  identity_roles = {
    "plan-reader-dev"  = { identity = "plan", role = "Reader", scope = azurerm_resource_group.env["dev"].id }
    "plan-reader-prod" = { identity = "plan", role = "Reader", scope = azurerm_resource_group.env["prod"].id }
    "plan-state"       = { identity = "plan", role = "Storage Blob Data Contributor", scope = azurerm_storage_account.state.id }

    "dev-owner"    = { identity = "dev", role = "Owner", scope = azurerm_resource_group.env["dev"].id }
    "dev-acr-push" = { identity = "dev", role = "AcrPush", scope = azurerm_container_registry.acr.id }
    "dev-acr-rbac" = { identity = "dev", role = "Role Based Access Control Administrator", scope = azurerm_container_registry.acr.id }
    "dev-state"    = { identity = "dev", role = "Storage Blob Data Contributor", scope = azurerm_storage_account.state.id }

    "prod-owner"    = { identity = "prod", role = "Owner", scope = azurerm_resource_group.env["prod"].id }
    "prod-acr-pull" = { identity = "prod", role = "AcrPull", scope = azurerm_container_registry.acr.id }
    "prod-acr-rbac" = { identity = "prod", role = "Role Based Access Control Administrator", scope = azurerm_container_registry.acr.id }
    "prod-state"    = { identity = "prod", role = "Storage Blob Data Contributor", scope = azurerm_storage_account.state.id }
  }
}

resource "azurerm_federated_identity_credential" "gh" {
  for_each = local.federated_subjects

  name      = "github-${each.key}"
  parent_id = azurerm_user_assigned_identity.gh[each.value.identity].id
  issuer    = "https://token.actions.githubusercontent.com"
  audience  = ["api://AzureADTokenExchange"]
  subject   = each.value.subject
}

resource "azurerm_role_assignment" "gh" {
  for_each = local.identity_roles

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.gh[each.value.identity].principal_id
  principal_type       = "ServicePrincipal"
}
