environment        = "prod"
initials           = "mt"
owner              = "Mohamed Toure"
expires_on         = "2026-11-30"
vnet_address_space = "10.20.0.0/16"
log_daily_quota_gb = 1

kubernetes_version = "1.36"
aks_node_vm_size   = "Standard_D2s_v5"
aks_node_min_count = 2
aks_node_max_count = 4
aks_zones          = ["1", "2", "3"]
aks_cluster_admin_principal_ids = {
  owner  = "5f85d2aa-7aaa-4926-b76b-d57833109ba6"
  github = "87e8b488-9fc5-4b0b-8e71-68049558d60a"
}
