# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# Optional Azure Monitor metric alert: ledger backend unhealthy on Application Gateway.
# Separate from WAF/route rules — TLS/cert or ACL issues surface as unhealthy backends.

locals {
  monitor_action_ids = concat(
    var.gateway_monitor_additional_action_group_ids,
    compact([try(azurerm_monitor_action_group.gateway[0].id, "")]),
  )

  gateway_ledger_backend_http_settings_effective = trimspace(var.gateway_ledger_backend_http_settings_name) != "" ? trimspace(var.gateway_ledger_backend_http_settings_name) : "depa-inferencing-backend-http-settings"

  gateway_monitor_alerts_deployed = (
    var.gateway_monitor_unhealthy_alert_enabled &&
    length(local.monitor_action_ids) > 0
  )

  # Azure resource names (override via module variables or use defaults from var.name).
  gateway_monitor_action_group_azure_name = trimspace(var.gateway_monitor_action_group_name) != "" ? trimspace(var.gateway_monitor_action_group_name) : "${var.name}-monitor-ag"

  gateway_monitor_metric_alert_azure_name = trimspace(var.gateway_monitor_metric_alert_name) != "" ? trimspace(var.gateway_monitor_metric_alert_name) : "${var.name}-ledger-backend-unhealthy"

  gateway_monitor_metric_alert_description = trimspace(var.gateway_monitor_unhealthy_alert_description) != "" ? trimspace(var.gateway_monitor_unhealthy_alert_description) : "Ledger backend (${local.gateway_ledger_backend_http_settings_effective}) unhealthy for ${var.name}"

  # short_name ≤12 chars; Azure allows letters, numbers, hyphens in practice — normalize.
  gateway_monitor_action_group_short_name_derived = substr(lower(replace(replace(var.name, "-", ""), ".", "")), 0, 12)
  gateway_monitor_action_group_short_name_custom  = trimspace(var.gateway_monitor_action_group_short_name) != "" ? substr(lower(replace(replace(trimspace(var.gateway_monitor_action_group_short_name), "-", ""), ".", "")), 0, 12) : ""

  gateway_monitor_action_group_short_name_effective = local.gateway_monitor_action_group_short_name_custom != "" ? local.gateway_monitor_action_group_short_name_custom : (local.gateway_monitor_action_group_short_name_derived != "" ? local.gateway_monitor_action_group_short_name_derived : "kmsagwmonxxx")
}

resource "azurerm_monitor_action_group" "gateway" {
  count = length(var.gateway_monitor_alert_email_addresses) > 0 ? 1 : 0

  name                = local.gateway_monitor_action_group_azure_name
  resource_group_name = var.resource_group_name
  short_name          = local.gateway_monitor_action_group_short_name_effective
  location            = "global"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.gateway_monitor_alert_email_addresses
    content {
      name                    = email_receiver.key
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

resource "azurerm_monitor_metric_alert" "gateway_ledger_backend_unhealthy" {
  count = local.gateway_monitor_alerts_deployed ? 1 : 0

  name                = local.gateway_monitor_metric_alert_azure_name
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_gateway.this.id]
  description         = local.gateway_monitor_metric_alert_description

  severity      = var.gateway_monitor_unhealthy_alert_severity
  enabled       = true
  auto_mitigate = false
  # Valid Azure evaluation granularity for platform metrics — keep fixed.
  frequency   = var.gateway_monitor_alert_frequency
  window_size = var.gateway_monitor_alert_window_size

  criteria {
    aggregation      = "Average"
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    operator         = "GreaterThan"
    threshold        = 0

    dimension {
      name     = "BackendSettingsPool"
      operator = "Include"
      values   = [local.gateway_ledger_backend_http_settings_effective]
    }
  }

  dynamic "action" {
    for_each = local.monitor_action_ids
    content {
      action_group_id = action.value
    }
  }
}
