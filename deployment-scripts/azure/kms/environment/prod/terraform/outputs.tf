# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "kms_resource_group_id" {
  description = "Resource ID for the KMS environment resource group."
  value       = module.kms.resource_group_id
}

output "kms_resource_group_name" {
  description = "Name of the KMS environment resource group."
  value       = module.kms.resource_group_name
}

output "kms_managed_identity_id" {
  description = "Resource ID of the managed identity created for KMS."
  value       = module.kms.managed_identity_id
}

output "kms_managed_identity_client_id" {
  description = "Client ID of the managed identity created for KMS."
  value       = module.kms.managed_identity_client_id
}

output "kms_managed_identity_principal_id" {
  description = "Principal ID of the managed identity created for KMS."
  value       = module.kms.managed_identity_principal_id
}

output "kms_key_vault_id" {
  description = "Resource ID of the Azure Key Vault provisioned for KMS."
  value       = module.kms.key_vault_id
}

output "kms_key_vault_name" {
  description = "Name of the Azure Key Vault provisioned for KMS."
  value       = module.kms.key_vault_name
}

output "kms_key_vault_uri" {
  description = "Vault URI endpoint for the KMS Azure Key Vault."
  value       = module.kms.key_vault_uri
}

output "kms_virtual_network_name" {
  description = "Name of the KMS Virtual Network."
  value       = module.kms.virtual_network_name
}

output "kms_gateway_subnet_id" {
  description = "Resource ID of the Application Gateway subnet."
  value       = module.kms.gateway_subnet_id
}

output "kms_ledger_endpoint" {
  description = "Ledger Endpoint for the Confidential Ledger."
  value       = module.kms.ledger_endpoint
}

output "kms_confidential_ledger_name" {
  description = "Name of the Confidential Ledger."
  value       = module.kms.confidential_ledger_name
}

