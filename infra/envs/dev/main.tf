# Thin root stack: reads the environment's resource group (created by
# bootstrap) and calls the shared modules. dev and prod differ only in
# terraform.tfvars and the backend key.

data "azurerm_resource_group" "env" {
  name = "rg-hello-${var.initials}-${var.environment}"
}

locals {
  suffix = "hello-${var.initials}-${var.environment}"

  tags = {
    owner        = var.owner
    env          = var.environment
    project      = "hello"
    "managed-by" = "terraform"
    "expires-on" = var.expires_on
  }
}

module "network" {
  source = "../../modules/network"

  name                = "vnet-${local.suffix}"
  location            = data.azurerm_resource_group.env.location
  resource_group_name = data.azurerm_resource_group.env.name
  address_space       = var.vnet_address_space
  tags                = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                = "log-${local.suffix}"
  location            = data.azurerm_resource_group.env.location
  resource_group_name = data.azurerm_resource_group.env.name
  daily_quota_gb      = var.log_daily_quota_gb
  tags                = local.tags
}

data "azurerm_container_registry" "shared" {
  name                = "crhello${var.initials}"
  resource_group_name = "rg-hello-${var.initials}-shared"
}

module "aks" {
  source = "../../modules/aks"

  name                        = "aks-${local.suffix}"
  location                    = data.azurerm_resource_group.env.location
  resource_group_name         = data.azurerm_resource_group.env.name
  kubernetes_version          = var.kubernetes_version
  subnet_id                   = module.network.aks_subnet_id
  node_vm_size                = var.aks_node_vm_size
  node_min_count              = var.aks_node_min_count
  node_max_count              = var.aks_node_max_count
  zones                       = var.aks_zones
  log_analytics_workspace_id  = module.monitoring.workspace_id
  acr_id                      = data.azurerm_container_registry.shared.id
  cluster_admin_principal_ids = var.aks_cluster_admin_principal_ids
  tags                        = local.tags
}