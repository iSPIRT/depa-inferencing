# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

variable "resource_group_name" {
  type        = string
  description = "Resource group that hosts the Application Gateway and where the reconciler resources are created."
}

variable "location" {
  type        = string
  description = "Azure region for the reconciler resources."
}

variable "subscription_id" {
  type        = string
  description = "Subscription ID that contains the Application Gateway (used by the function to set its ARM context)."
}

variable "application_gateway_id" {
  type        = string
  description = "Resource ID of the Application Gateway whose ledger trusted-root certificate is reconciled."
}

variable "application_gateway_name" {
  type        = string
  description = "Name of the Application Gateway."
}

variable "ledger_name" {
  type        = string
  description = "Confidential Ledger name (used to fetch the current TLS identity certificate)."
}

variable "trusted_root_certificate_name" {
  type        = string
  description = "Name of the trusted root certificate entry on the Application Gateway backend HTTP settings."
  default     = "ledger-root-cert"
}

variable "ledger_identity_base_url" {
  type        = string
  description = "Base URL of the Confidential Ledger identity service."
  default     = "https://identity.confidential-ledger.core.azure.com"
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique storage account name for the Function App (<=24 lowercase alphanumeric chars)."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "function_app_name" {
  type        = string
  description = "Name of the Function App that runs the reconciler."
}

variable "service_plan_name" {
  type        = string
  description = "Name of the App Service (consumption) plan. Defaults to <function_app_name>-plan when empty."
  default     = ""
}

variable "reconcile_schedule" {
  type        = string
  description = "NCRONTAB schedule for the timer trigger. Default: every minute."
  default     = "0 */1 * * * *"
}

variable "role_definition_name" {
  type        = string
  description = "Name for the custom role granted to the function identity (scoped to the Application Gateway). Defaults to <function_app_name>-agw-writer when empty."
  default     = ""
}

variable "alert_enabled" {
  type        = bool
  description = "If true, create an UnhealthyHostCount metric alert on the gateway wired to an action group that calls the function's HTTP trigger for immediate reconciliation."
  default     = true
}

variable "alert_severity" {
  type        = number
  description = "Severity (0-4) for the ledger-backend-unhealthy alert."
  default     = 1
}

variable "alert_frequency" {
  type        = string
  description = "How often the alert rule evaluates (ISO8601 duration, e.g. PT1M)."
  default     = "PT1M"
}

variable "alert_window_size" {
  type        = string
  description = "Aggregation window for the alert (ISO8601 duration, e.g. PT5M)."
  default     = "PT5M"
}

variable "ledger_backend_http_settings_name" {
  type        = string
  description = "Backend HTTP settings name that routes to the ledger (metric dimension BackendSettingsPool)."
  default     = "depa-inferencing-backend-http-settings"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the reconciler resources."
  default     = {}
}
