locals {
  app = "hello"

  # Tags every resource must carry (architecture section: naming and tags)
  base_tags = {
    owner        = var.owner
    project      = local.app
    "managed-by" = "terraform"
    "expires-on" = var.expires_on
  }

  environments = toset(["dev", "prod"])
}

# P3.2: shared group for state, ACR and the GitHub identities
resource "azurerm_resource_group" "shared" {
  name     = "rg-${local.app}-${var.initials}-shared"
  location = var.location
  tags     = merge(local.base_tags, { env = "shared" })
}

# P3.2: one group per environment, created here so each GitHub identity
# can be scoped to a single environment; the env stacks read them with
# data "azurerm_resource_group".
resource "azurerm_resource_group" "env" {
  for_each = local.environments

  name     = "rg-${local.app}-${var.initials}-${each.key}"
  location = var.location
  tags     = merge(local.base_tags, { env = each.key })
}
