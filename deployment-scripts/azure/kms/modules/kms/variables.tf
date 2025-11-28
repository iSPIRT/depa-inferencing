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

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags to append to the default KMS tag set."
  default     = {}
}

