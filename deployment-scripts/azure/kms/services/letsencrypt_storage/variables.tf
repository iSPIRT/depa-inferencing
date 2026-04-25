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

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}
