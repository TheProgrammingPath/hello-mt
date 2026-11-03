environment        = "dev"
initials           = "mt"
owner              = "Mohamed Toure"
expires_on         = "2026-11-30"
vnet_address_space = "10.10.0.0/16"
log_daily_quota_gb = 0.5

kubernetes_version = "1.36"
aks_node_vm_size   = "Standard_D2s_v5"
aks_node_min_count = 1
aks_node_max_count = 3
aks_zones          = []
aks_cluster_admin_principal_ids = {
  owner  = "5f85d2aa-7aaa-4926-b76b-d57833109ba6"
  github = "4f3f9803-2509-44df-bb66-810652e99afb"
}