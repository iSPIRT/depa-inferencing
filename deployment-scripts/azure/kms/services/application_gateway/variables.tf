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
  default     = "Detection"
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

variable "waf_sqli_rule_overrides_enabled" {
  type        = bool
  description = "OWASP CRS: disable rules 942340/942430/942440 on this policy only (KMS JSON false positives). Required before Prevention if key/unwrap POSTs must succeed."
  default     = true
}

variable "waf_public_allowlist_enabled" {
  type        = bool
  description = "If true: block RequestUri outside default allow regex (or waf_allowed_public_uri_regex when set)."
  default     = true
}

variable "waf_allowed_public_uri_regex" {
  type        = string
  description = "Non-empty → full permitted RequestUri regex (after WAF transforms). Empty → built-in: listpubkeys (+ optional /, ?query); key & unwrapkey require fmt=tink in query."
  default     = ""
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

variable "http2_enabled" {
  type        = bool
  description = "Enable HTTP/2 on the Application Gateway frontend."
  default     = true
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

variable "public_ip_id" {
  type        = string
  description = "Optional resource ID of an existing public IP to use. If empty, a new public IP is created."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Application Gateway."
  default     = {}
}

variable "allowed_hostname" {
  type        = string
  description = "Allowed hostname for Host header validation. Requests with Host headers not matching this hostname will be blocked."
}

variable "acme_challenge_backend_fqdn" {
  type        = string
  description = "FQDN of the backend that serves ACME HTTP-01 challenges under /.well-known/acme-challenge/* (typically the static website host of a private storage account, e.g. <account>.z29.web.core.windows.net)."
}

# --- Azure Monitor: backend health alerts (Terraform; independent of WAF rules) ---
variable "gateway_monitor_unhealthy_alert_enabled" {
  type        = bool
  description = "If true, create a metric alert when Unhealthy Host Count is greater than zero for the ledger backend HTTP settings. Requires action groups via gateway_monitor_alert_email_addresses and/or gateway_monitor_additional_action_group_ids."
  default     = false
}

variable "gateway_monitor_alert_email_addresses" {
  type        = map(string)
  description = "Creates an Azure Monitor Action Group with email receivers: map keys = receiver names, values = email addresses. Omit or empty to skip; use gateway_monitor_additional_action_group_ids alone instead."
  default     = {}
}

variable "gateway_monitor_additional_action_group_ids" {
  type        = list(string)
  description = "Extra Action Group resource IDs to attach to the backend-unhealthy alert (e.g. central ops group)."
  default     = []
}

variable "gateway_ledger_backend_http_settings_name" {
  type        = string
  description = "Backend HTTP settings name for Confidential Ledger routing (metric dimension BackendSettingsPool). Leave empty for default depa-inferencing-backend-http-settings."
  default     = ""
}

variable "gateway_monitor_unhealthy_alert_severity" {
  type        = number
  description = "Alert severity 0–4."
  default     = 2
}

variable "gateway_monitor_alert_frequency" {
  type        = string
  description = "How often the alert rule checks the metric (Azure Monitor supported period, e.g. PT1M)."
  default     = "PT1M"
}

variable "gateway_monitor_alert_window_size" {
  type        = string
  description = "Rolling window for aggregation (must be ≥ frequency; typical PT5M)."
  default     = "PT5M"
}

variable "gateway_monitor_action_group_name" {
  type        = string
  description = "Azure resource name for the monitor Action Group. Leave empty for \"<application_gateway_name>-monitor-ag\"."
  default     = ""
}

variable "gateway_monitor_metric_alert_name" {
  type        = string
  description = "Azure resource name for the UnhealthyHostCount metric alert. Leave empty for \"<application_gateway_name>-ledger-backend-unhealthy\"."
  default     = ""
}

variable "gateway_monitor_action_group_short_name" {
  type        = string
  description = "Action group short name (≤12 chars for Azure SMS slot). Leave empty to derive from application gateway name."
  default     = ""
}

variable "gateway_monitor_unhealthy_alert_description" {
  type        = string
  description = "Metric alert description text in Azure Portal. Leave empty for a built-in message naming the ledger HTTP settings and gateway."
  default     = ""
}

