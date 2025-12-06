# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "operator" {
  type        = string
  description = "Operator code used when constructing resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment identifier (dev, test, prod, etc.)."
}

variable "tenant_id" {
  type        = string
  description = "Azure Active Directory tenant identifier used by dependent resources like Key Vault."
}

variable "region" {
  type        = string
  description = "Azure region where the workload will run."
}

variable "region_short" {
  type        = string
  description = "Short code for the Azure region, used in resource names."
}

variable "resource_group_name" {
  type        = string
  description = "Optional explicit resource group name override. If empty, a default name is generated."
  default     = ""
}

variable "key_vault_name" {
  type        = string
  description = "Optional explicit key vault name override. Defaults to a convention-based value when empty."
  default     = ""
}

variable "managed_identity_name" {
  type        = string
  description = "Optional explicit name for the managed identity. Defaults to a convention-based value when empty."
  default     = ""
}

variable "certificate_name" {
  type        = string
  description = "Optional explicit name for the certificate. Defaults to a convention-based value when empty."
  default     = ""
}

variable "ledger_name" {
  type        = string
  description = "Optional explicit name for the confidential ledger. Defaults to a convention-based value when empty."
  default     = ""
}

variable "application_gateway_name" {
  type        = string
  description = "Optional explicit name for the application gateway. Defaults to a convention-based value when empty."
  default     = ""
}

variable "virtual_network_name" {
  type        = string
  description = "Optional explicit name for the virtual network. Defaults to a convention-based value when empty."
  default     = ""
}

variable "github_repository" {
  type        = string
  description = "GitHub repository in format 'owner/repo' for federated credential. Leave empty to disable."
  default     = ""
}

variable "github_branch" {
  type        = string
  description = "GitHub branch name for federated credential. Only used if github_repository is set."
  default     = ""
}

variable "ssl_certificate_name" {
  type        = string
  description = "Name of the SSL certificate in Key Vault for Application Gateway."
}

variable "diagnostics_log_analytics_workspace_name" {
  type        = string
  description = "Log Analytics workspace name for Application Gateway diagnostics. If empty, diagnostics are disabled."
  default     = ""
}

variable "diagnostics_log_analytics_workspace_resource_group_name" {
  type        = string
  description = "Resource group name of the Log Analytics workspace for Application Gateway diagnostics. If empty, defaults to the Application Gateway resource group."
  default     = ""
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags to append to the default KMS tag set."
  default     = {}
}

variable "storage_account_name" {
  type        = string
  description = "Optional explicit name for the ledger backup storage account. Must be globally unique, 3-24 characters, lowercase alphanumeric only. Defaults to a convention-based value when empty."
  default     = ""
}

variable "storage_account_tier" {
  type        = string
  description = "Defines the Tier to use for the storage account. Valid options are Standard and Premium."
  default     = "Standard"
}

variable "storage_account_replication_type" {
  type        = string
  description = "Defines the type of replication to use for the storage account. Valid options are LRS, GRS, RAGRS, ZRS, GZRS and RAGZRS."
  default     = "LRS"
}

variable "storage_file_share_name" {
  type        = string
  description = "Name of the file share for storing ledger backups."
  default     = "ledger-backup"
}

variable "storage_file_share_quota_gb" {
  type        = number
  description = "The maximum size of the file share in gigabytes for ledger backups. Must be greater than 0, and less than or equal to 102400."
  default     = 100
}

variable "additional_virtual_network_ids" {
  type        = list(string)
  description = "List of additional Virtual Network IDs to link the Key Vault private DNS zone to. This allows VMs in other VNets to access the Key Vault via private endpoint. NOTE: This variable is NOT used in the main KMS deployment - it is only used in the separate key-vault-networking deployment."
  default     = []
}

