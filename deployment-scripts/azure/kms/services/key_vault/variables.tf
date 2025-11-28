# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "name" {
  type        = string
  description = "Name of the Azure Key Vault."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that hosts the Key Vault."
}

variable "location" {
  type        = string
  description = "Azure region for the Key Vault."
}

variable "tenant_id" {
  type        = string
  description = "Azure Active Directory tenant ID associated with the Key Vault."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Key Vault."
  default     = {}
}

variable "admin_principal_ids" {
  type        = list(string)
  description = "Optional list of principal object IDs that should receive the Key Vault Administrator role."
  default     = []
}

variable "crypto_principal_ids" {
  type        = list(string)
  description = "List of principal object IDs that should be granted Key Vault Crypto User."
  default     = []
}

variable "certificate_name" {
  type        = string
  description = "Name of the certificate to create in the Key Vault."
  default     = "member-cert"
}

