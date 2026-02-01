# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "name" {
  type        = string
  description = "Name of the Virtual Network."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that hosts the Virtual Network."
}

variable "location" {
  type        = string
  description = "Azure region for the Virtual Network."
}

variable "address_space" {
  type        = list(string)
  description = "Address space for the Virtual Network."
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefixes" {
  type        = list(string)
  description = "Address prefixes for the Application Gateway subnet."
  default     = ["10.0.1.0/24"]
}

variable "private_endpoint_subnet_address_prefixes" {
  type        = list(string)
  description = "Address prefixes for the private endpoint subnet."
  default     = ["10.0.2.0/24"]
}

variable "kms_private_link_subnet_address_prefixes" {
  type        = list(string)
  description = "Address prefixes for the KMS private link subnet."
  default     = ["10.0.3.0/24"]
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Virtual Network."
  default     = {}
}

