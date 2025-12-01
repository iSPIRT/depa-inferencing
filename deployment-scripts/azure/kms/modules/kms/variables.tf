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

