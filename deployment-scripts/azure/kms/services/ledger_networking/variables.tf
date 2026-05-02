# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "name" {
  type        = string
  description = "Name of the Confidential Ledger (used for naming private endpoint and DNS records)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that hosts the ledger networking resources."
}

variable "location" {
  type        = string
  description = "Azure region for the private endpoint."
}

variable "private_link_service_alias" {
  type        = string
  description = "Alias of the Private Link Service for the Confidential Ledger (e.g., depa-inferencing-kms-prod-cin-pls.{guid}.centralindia.azure.privatelinkservice)."
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for the private endpoint."
}

variable "virtual_network_id" {
  type        = string
  description = "Virtual Network ID for linking the private DNS zone."
}

variable "vm_private_endpoint_subnet_id" {
  type        = string
  description = "Optional subnet ID in another VNet (e.g. the CI runner VNet) where a second private endpoint for the Confidential Ledger PLS should be created. Required if the runner VM needs private connectivity to the ledger."
  default     = ""
}

variable "vm_virtual_network_id" {
  type        = string
  description = "Virtual network ID where the runner / VM resides. Required if vm_private_endpoint_subnet_id is set; the confidential-ledger.azure.com private DNS zone is linked to this VNet so the runner resolves the ledger FQDN to a private IP."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the networking resources."
  default     = {}
}
