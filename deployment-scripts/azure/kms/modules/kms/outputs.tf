# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "resource_group_id" {
  description = "Resource ID of the provisioned KMS resource group."
  value       = module.resource_group.id
}

output "resource_group_name" {
  description = "Name of the provisioned KMS resource group."
  value       = module.resource_group.name
}

output "resource_group_location" {
  description = "Azure region where the KMS resource group resides."
  value       = module.resource_group.location
}

output "managed_identity_id" {
  description = "Resource ID of the KMS managed identity."
  value       = module.managed_identity.id
}

output "managed_identity_client_id" {
  description = "Client ID of the KMS managed identity."
  value       = module.managed_identity.client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID (object ID) of the KMS managed identity."
  value       = module.managed_identity.principal_id
}

output "key_vault_id" {
  description = "Resource ID of the KMS Key Vault."
  value       = module.key_vault.id
}

output "key_vault_name" {
  description = "Name of the KMS Key Vault."
  value       = module.key_vault.name
}

output "key_vault_uri" {
  description = "Vault URI endpoint for the KMS Key Vault."
  value       = module.key_vault.uri
}

output "application_gateway_endpoint" {
  description = "Endpoint URL of the Application Gateway."
  value       = module.application_gateway.endpoint
}

output "application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway."
  value       = module.application_gateway.public_ip_address
}

output "ledger_endpoint_name" {
  description = "Name of the Confidential Ledger endpoint."
  value       = module.confidential_ledger.name
}

