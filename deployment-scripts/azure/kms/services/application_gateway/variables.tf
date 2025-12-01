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

variable "backend_hostname" {
  type        = string
  description = "Hostname to use in the Host header when forwarding requests to the backend. If not provided, uses the backend address."
  default     = ""
}

variable "backend_port" {
  type        = number
  description = "Backend port for the Application Gateway backend pool."
  default     = 443
}

variable "sku_name" {
  type        = string
  description = "SKU name for the Application Gateway."
  default     = "WAF_v2"
}

variable "sku_tier" {
  type        = string
  description = "SKU tier for the Application Gateway."
  default     = "WAF_v2"
}

variable "waf_firewall_mode" {
  type        = string
  description = "The Web Application Firewall mode. Possible values are Detection and Prevention."
  default     = "Prevention"
}

variable "waf_rule_set_type" {
  type        = string
  description = "The Type of the Rule Set used for this Web Application Firewall."
  default     = "OWASP"
}

variable "waf_rule_set_version" {
  type        = string
  description = "The Version of the Rule Set used for this Web Application Firewall."
  default     = "3.2"
}

variable "capacity" {
  type        = number
  description = "Capacity (instance count) for the Application Gateway."
  default     = 2
}

variable "zones" {
  type        = list(string)
  description = "Availability zones for the Application Gateway. Defaults to all zones [1, 2, 3] for high availability."
  default     = ["1", "2", "3"]
}

variable "ssl_certificate_name" {
  type        = string
  description = "Name of the SSL certificate in Key Vault for HTTPS listener."
}

variable "key_vault_uri" {
  type        = string
  description = "Key Vault URI (e.g., https://vault-name.vault.azure.net). Required if ssl_certificate_name is provided."
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

variable "managed_identity_id" {
  type        = string
  description = "Resource ID of the User-Assigned Managed Identity for the Application Gateway."
}

variable "diagnostics_log_analytics_workspace_name" {
  type        = string
  description = "Log Analytics workspace name for Application Gateway diagnostics. If empty, diagnostics are disabled."
  default     = ""
}

variable "diagnostics_log_analytics_workspace_resource_group_name" {
  type        = string
  description = "Resource group name of the Log Analytics workspace for Application Gateway diagnostics. If empty, defaults to the Application Gateway resource group."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Application Gateway."
  default     = {}
}

