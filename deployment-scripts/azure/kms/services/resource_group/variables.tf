# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "name" {
  type        = string
  description = "Name to assign to the Azure resource group."
}

variable "location" {
  type        = string
  description = "Azure region for the resource group."
}

variable "tags" {
  type        = map(string)
  description = "Optional tags applied to the resource group."
  default     = {}
}

