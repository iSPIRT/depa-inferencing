# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "name" {
  type        = string
  description = "Name of the Key Vault (used for naming private endpoint and DNS records)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that hosts the Key Vault networking resources."
}

variable "location" {
  type        = string
  description = "Azure region for the private endpoint."
}

variable "key_vault_id" {
  type        = string
  description = "Resource ID of the Key Vault to create private endpoint for."
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for the private endpoint."
}

variable "virtual_network_id" {
  type        = string
  description = "Virtual Network ID for linking the private DNS zone."
}

variable "additional_virtual_network_ids" {
  type        = list(string)
  description = "List of additional Virtual Network IDs to link the private DNS zone to. This allows VMs in other VNets to access the Key Vault via private endpoint."
  default     = []
}

variable "vm_private_endpoint_subnet_id" {
  type        = string
  description = "Optional subnet ID for creating a private endpoint for the externally provisioned VM. If provided, a separate private endpoint will be created in this subnet."
  default     = ""
}

variable "vm_virtual_network_id" {
  type        = string
  description = "Optional Virtual Network ID where the externally provisioned VM resides. Required if vm_private_endpoint_subnet_id is provided."
  default     = ""
}

variable "kms_private_endpoint_id" {
  type        = string
  description = "Resource ID of the KMS private endpoint (from Phase 1 KMS deployment). If provided, a DNS A record will be created for KMS."
  default     = ""
}

variable "kms_private_dns_record_name" {
  type        = string
  description = "DNS record name for KMS private link (e.g., depa-inferencing-kms-prod-cin-pls-api)."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the networking resources."
  default     = {}
}

