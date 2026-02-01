# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "private_dns_zone_id" {
  description = "Resource ID of the private DNS zone."
  value       = azurerm_private_dns_zone.key_vault.id
}

output "private_dns_zone_name" {
  description = "Name of the private DNS zone."
  value       = azurerm_private_dns_zone.key_vault.name
}

output "kms_private_dns_a_record_fqdn" {
  description = "FQDN of the KMS private DNS A record."
  value       = length(azurerm_private_dns_a_record.kms_private_link) > 0 ? "${azurerm_private_dns_a_record.kms_private_link[0].name}.${azurerm_private_dns_zone.key_vault.name}" : ""
}

output "private_endpoint_id" {
  description = "Resource ID of the private endpoint for Key Vault."
  value       = azurerm_private_endpoint.key_vault.id
}

output "vm_private_endpoint_id" {
  description = "Resource ID of the private endpoint for the externally provisioned VM (if configured)."
  value       = var.vm_private_endpoint_subnet_id != "" ? azurerm_private_endpoint.key_vault_vm[0].id : null
}

