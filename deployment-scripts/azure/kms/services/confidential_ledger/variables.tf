# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "name" {
  type        = string
  description = "Name of the Azure Confidential Ledger."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that hosts the Confidential Ledger."
}

variable "location" {
  type        = string
  description = "Azure region for the Confidential Ledger."
}

variable "ledger_type" {
  type        = string
  description = "Type of the Confidential Ledger."
  default     = "Public"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Confidential Ledger."
  default     = {}
}

variable "azuread_based_service_principal_tenant_id" {
  type        = string
  description = "Tenant ID for the Azure AD based service principal."
}

variable "azuread_based_service_principal_principal_id" {
  type        = string
  description = "Principal ID (object ID) for the Azure AD based service principal."
}

variable "key_vault_id" {
  type        = string
  description = "Resource ID of the Key Vault containing the certificate."
}

variable "certificate_name" {
  type        = string
  description = "Name of the certificate in Key Vault."
}

variable "logs_storage_account_id" {
  type        = string
  description = "Resource ID of the storage account for storing Confidential Ledger logs. If empty, diagnostics are disabled."
  default     = ""
}

