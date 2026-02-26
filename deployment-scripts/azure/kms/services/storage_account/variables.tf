# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "name" {
  type        = string
  description = "Name of the storage account. Must be globally unique, 3-24 characters, lowercase alphanumeric only."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group where the storage account will be created."
}

variable "location" {
  type        = string
  description = "Azure region where the storage account will be created."
}

variable "account_tier" {
  type        = string
  description = "Defines the Tier to use for this storage account. Valid options are Standard and Premium."
  default     = "Standard"
}

variable "account_replication_type" {
  type        = string
  description = "Defines the type of replication to use for this storage account. Valid options are LRS, GRS, RAGRS, ZRS, GZRS and RAGZRS."
  default     = "LRS"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the storage account."
  default     = {}
}

