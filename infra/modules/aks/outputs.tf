output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "node_resource_group" {
  description = "Resource group AKS manages for nodes, load balancers and public IPs."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "kubelet_object_id" {
  description = "Object ID of the kubelet managed identity (has AcrPull)."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}
