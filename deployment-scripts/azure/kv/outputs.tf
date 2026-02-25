output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  description = "Name of the storage account."
  value       = azurerm_storage_account.sa.name
}

output "storage_primary_key" {
  description = "Primary key for the storage account (for upload step)."
  value       = azurerm_storage_account.sa.primary_access_key
  sensitive   = true
}

output "aci_ip_address" {
  description = "Public IP address of the KV container group (for getValues test)."
  value       = azurerm_container_group.kv.ip_address
}

output "aci_fqdn" {
  description = "FQDN of the container group (if configured)."
  value       = azurerm_container_group.kv.fqdn
}

output "aci_name" {
  description = "Name of the container group (for logs step)."
  value       = azurerm_container_group.kv.name
}

output "file_share_name" {
  description = "Azure Files share name (for upload step)."
  value       = azurerm_storage_share.share.name
}

output "aci_identity_principal_id" {
  description = "Principal ID of the container group's system-assigned managed identity (for RBAC, e.g. Key Vault access)."
  value       = one(azurerm_container_group.kv.identity).principal_id
}
