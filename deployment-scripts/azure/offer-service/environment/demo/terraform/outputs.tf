output "aks_cluster_name" {
  description = "Name of the AKS cluster (for kubectl / az aks get-credentials)."
  value       = module.offer.aks_cluster_name
}

output "aks_resource_group_name" {
  description = "Resource group containing the AKS cluster."
  value       = module.offer.aks_resource_group_name
}