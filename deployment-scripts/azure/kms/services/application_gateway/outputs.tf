# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "id" {
  description = "Resource ID of the Application Gateway."
  value       = azurerm_application_gateway.this.id
}

output "name" {
  description = "Name of the Application Gateway."
  value       = azurerm_application_gateway.this.name
}

output "public_ip_address" {
  description = "Public IP address of the Application Gateway."
  value       = local.public_ip_address
}

output "public_ip_id" {
  description = "Resource ID of the public IP address."
  value       = local.public_ip_id
}

output "fqdn" {
  description = "FQDN of the Application Gateway."
  value       = local.public_ip_fqdn
}

output "endpoint" {
  description = "Endpoint URL of the Application Gateway (using FQDN if available, otherwise IP address)."
  value = coalesce(
    local.public_ip_fqdn != null && local.public_ip_fqdn != "" ? "http://${local.public_ip_fqdn}" : null,
    "http://${local.public_ip_address}"
  )
}

output "gateway_monitor_action_group_id" {
  description = "Azure Monitor Action Group ID when gateway_monitor_alert_email_addresses is non-empty."
  value       = length(azurerm_monitor_action_group.gateway) > 0 ? azurerm_monitor_action_group.gateway[0].id : null
}

output "gateway_ledger_backend_unhealthy_alert_id" {
  description = "Metric alert rule ID when gateway_monitor_unhealthy_alert_enabled creates the ledger-backend-unhealthy alert."
  value       = length(azurerm_monitor_metric_alert.gateway_ledger_backend_unhealthy) > 0 ? azurerm_monitor_metric_alert.gateway_ledger_backend_unhealthy[0].id : null
}

output "gateway_monitor_resolved_action_group_name" {
  description = "Effective Azure name for the monitor Action Group (after gateway_monitor_action_group_name override)."
  value       = local.gateway_monitor_action_group_azure_name
}

output "gateway_monitor_resolved_metric_alert_name" {
  description = "Effective Azure name for the backend-unhealthy metric alert (after gateway_monitor_metric_alert_name override)."
  value       = local.gateway_monitor_metric_alert_azure_name
}

output "gateway_monitor_resolved_action_group_short_name" {
  description = "Effective action group short name (≤12 chars) used in Azure."
  value       = local.gateway_monitor_action_group_short_name_effective
}

