# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "function_app_id" {
  description = "Resource ID of the reconciler Function App."
  value       = azurerm_windows_function_app.this.id
}

output "function_app_name" {
  description = "Name of the reconciler Function App."
  value       = azurerm_windows_function_app.this.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the reconciler Function App."
  value       = azurerm_windows_function_app.this.default_hostname
}

output "function_identity_principal_id" {
  description = "Principal ID of the Function App's system-assigned managed identity."
  value       = azurerm_windows_function_app.this.identity[0].principal_id
}

output "role_definition_id" {
  description = "ID of the custom role granted to the function identity."
  value       = azurerm_role_definition.reconciler.role_definition_resource_id
}

output "action_group_id" {
  description = "Action group ID that invokes the function on unhealthy backend (null when alert_enabled = false)."
  value       = var.alert_enabled ? azurerm_monitor_action_group.this[0].id : null
}

output "metric_alert_id" {
  description = "Metric alert ID for ledger backend health (null when alert_enabled = false)."
  value       = var.alert_enabled ? azurerm_monitor_metric_alert.ledger_backend_unhealthy[0].id : null
}
