# Module: aks. AKS cluster (Free tier, Azure CNI Overlay with Cilium,
# Entra ID with Azure RBAC, local accounts disabled, app routing add-on,
# Container insights) and its role assignments.

data "azurerm_client_config" "current" {}

# Accepted risk (see ADR): hosted runners have no fixed IPs; API access needs Entra ID + Azure RBAC, local accounts disabled.
#trivy:ignore:AZU-0041
resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  # No static admin credentials: every kubectl call is an Entra identity
  # checked against Azure RBAC.
  local_account_disabled            = true
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  default_node_pool {
    name                        = "system"
    temporary_name_for_rotation = "systemtmp"
    vm_size                     = var.node_vm_size
    vnet_subnet_id              = var.subnet_id
    orchestrator_version        = var.kubernetes_version
    os_disk_size_gb             = 64
    os_disk_type                = "Managed"
    auto_scaling_enabled        = true
    min_count                   = var.node_min_count
    max_count                   = var.node_max_count
    zones                       = length(var.zones) > 0 ? var.zones : null
    tags                        = var.tags

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  # Managed nginx ingress (app routing add-on)
  web_app_routing {
    dns_zone_ids = []
  }

  # Container insights
  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  tags = var.tags

  lifecycle {
    # The cluster autoscaler owns the node count.
    ignore_changes = [default_node_pool[0].node_count]
  }
}

# Nodes pull images with the kubelet managed identity, not a registry password.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

# The cluster identity manages load balancer and NIC resources in our subnet.
resource "azurerm_role_assignment" "cluster_subnet" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# kubectl access through Azure RBAC for the owner and the environment's GitHub identity.
resource "azurerm_role_assignment" "cluster_admin" {
  for_each = var.cluster_admin_principal_ids

  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}
