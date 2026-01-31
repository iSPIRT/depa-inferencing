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

output "kms_application_gateway_endpoint" {
  description = "Endpoint URL of the Application Gateway."
  value       = module.kms.application_gateway_endpoint
}

output "kms_application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway."
  value       = module.kms.application_gateway_public_ip
}

output "kms_ledger_endpoint_name" {
  description = "Name of the Confidential Ledger endpoint."
  value       = module.kms.ledger_endpoint_name
}

output "kms_logs_storage_account_id" {
  description = "Resource ID of the storage account for KMS logs."
  value       = module.kms.logs_storage_account_id
}

output "kms_logs_storage_account_name" {
  description = "Name of the storage account for KMS logs."
  value       = module.kms.logs_storage_account_name
}

output "kms_logs_storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint URL of the storage account for KMS logs."
  value       = module.kms.logs_storage_account_primary_blob_endpoint
}

