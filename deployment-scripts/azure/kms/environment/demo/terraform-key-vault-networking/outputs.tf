# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "key_vault_private_endpoint_id" {
  description = "Resource ID of the Key Vault private endpoint."
  value       = module.key_vault_networking.private_endpoint_id
}

output "key_vault_private_dns_zone_id" {
  description = "Resource ID of the private DNS zone for Key Vault."
  value       = module.key_vault_networking.private_dns_zone_id
}

output "key_vault_private_dns_zone_name" {
  description = "Name of the private DNS zone for Key Vault."
  value       = module.key_vault_networking.private_dns_zone_name
}

output "application_gateway_id" {
  description = "Resource ID of the Application Gateway that will use the Key Vault private endpoint."
  value       = data.azurerm_application_gateway.kms.id
}

output "application_gateway_name" {
  description = "Name of the Application Gateway that will use the Key Vault private endpoint."
  value       = data.azurerm_application_gateway.kms.name
}

