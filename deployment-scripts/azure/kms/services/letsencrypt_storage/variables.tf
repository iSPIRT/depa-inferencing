# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "name" {
  type        = string
  description = "Storage account name. Must be globally unique, all-lowercase, 3-24 chars."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that hosts the storage account and private DNS resources."
}

variable "location" {
  type        = string
  description = "Azure region for the storage account and private endpoint."
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID where the storage account web private endpoint is created."
}

variable "virtual_network_id" {
  type        = string
  description = "Virtual network ID that the privatelink.web.core.windows.net DNS zone is linked to."
}

variable "vm_private_endpoint_subnet_id" {
  type        = string
  description = "Optional subnet ID in another VNet (e.g. the CI runner VNet) where a second private endpoint for the storage web subresource should be created. Required for the renewal workflow when the runner is not in the KMS VNet."
  default     = ""
}

variable "vm_virtual_network_id" {
  type        = string
  description = "Virtual network ID where the runner / VM resides. Required if vm_private_endpoint_subnet_id is set; the privatelink.web.core.windows.net DNS zone is linked to this VNet so the runner can resolve the storage account to a private IP."
  default     = ""
}

variable "ci_principal_id" {
  type        = string
  description = "Object ID of the CI principal (the managed identity / service principal used by the renewal workflow). Granted Storage Blob Data Contributor on this account so `az storage blob upload --auth-mode login` can write challenge tokens. Subscription-level Contributor is a control-plane role and does NOT grant blob data-plane access."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}
