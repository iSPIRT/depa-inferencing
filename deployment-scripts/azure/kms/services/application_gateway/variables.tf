# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "name" {
  type        = string
  description = "Name of the Application Gateway."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that hosts the Application Gateway."
}

variable "location" {
  type        = string
  description = "Azure region for the Application Gateway."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the Application Gateway."
}

variable "backend_address" {
  type        = string
  description = "Backend address (FQDN or IP) for the Application Gateway backend pool."
}

variable "backend_port" {
  type        = number
  description = "Backend port for the Application Gateway backend pool."
  default     = 443
}

variable "sku_name" {
  type        = string
  description = "SKU name for the Application Gateway."
  default     = "Standard_v2"
}

variable "sku_tier" {
  type        = string
  description = "SKU tier for the Application Gateway."
  default     = "Standard_v2"
}

variable "capacity" {
  type        = number
  description = "Capacity (instance count) for the Application Gateway."
  default     = 2
}

variable "ssl_certificate_name" {
  type        = string
  description = "Name of the SSL certificate for HTTPS listener. Leave empty to disable HTTPS."
  default     = ""
}

variable "health_probe_path" {
  type        = string
  description = "Path for the health probe."
  default     = "/"
}

variable "trusted_root_certificate" {
  type        = string
  description = "Trusted root certificate in PEM format for backend verification."
}

variable "trusted_root_certificate_name" {
  type        = string
  description = "Name for the trusted root certificate."
  default     = "ledger-root-cert"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Application Gateway."
  default     = {}
}

