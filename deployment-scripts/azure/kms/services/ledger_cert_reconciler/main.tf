# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.
#
# Ledger certificate reconciler.
#
# When the Confidential Ledger (CCF) restarts it regenerates its self-signed
# TLS identity certificate. The Application Gateway pins that certificate as the
# trusted root for the ledger backend, so a rotation breaks backend TLS and
# clients get 502s until the gateway is updated.
#
# This module deploys a PowerShell Function App that:
#   - Timer trigger (default: every minute) reconciles the gateway's trusted
#     root certificate against the ledger's live identity certificate.
#   - HTTP trigger performs the same reconcile on demand; it is wired to an
#     UnhealthyHostCount metric alert (via an action group) for immediate
#     reaction when a rotation is detected.
#
# The function authenticates with a system-assigned managed identity that is
# granted a custom role scoped to the single Application Gateway.

locals {
  service_plan_name    = var.service_plan_name != "" ? var.service_plan_name : "${var.function_app_name}-plan"
  role_definition_name = var.role_definition_name != "" ? var.role_definition_name : "${var.function_app_name}-agw-writer"

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "powershell"
    WEBSITE_RUN_FROM_PACKAGE = "${azurerm_storage_blob.package.url}${data.azurerm_storage_account_sas.package.sas}"
    AGW_RESOURCE_GROUP       = var.resource_group_name
    AGW_NAME                 = var.application_gateway_name
    LEDGER_NAME              = var.ledger_name
    ROOT_CERT_NAME           = var.trusted_root_certificate_name
    LEDGER_IDENTITY_BASE_URL = var.ledger_identity_base_url
    SUBSCRIPTION_ID          = var.subscription_id
    AGW_RECONCILE_SCHEDULE   = var.reconcile_schedule
  }
}

# --- Package the function code -------------------------------------------------

data "archive_file" "package" {
  type        = "zip"
  source_dir  = "${path.module}/function_src"
  output_path = "${path.module}/build/ledger_cert_reconciler.zip"
}

# --- Storage account for the Function App -------------------------------------

resource "azurerm_storage_account" "this" {
  name                            = var.storage_account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

resource "azurerm_storage_container" "deployments" {
  name                  = "deployments"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "package" {
  name                   = "ledger_cert_reconciler-${data.archive_file.package.output_md5}.zip"
  storage_account_name   = azurerm_storage_account.this.name
  storage_container_name = azurerm_storage_container.deployments.name
  type                   = "Block"
  source                 = data.archive_file.package.output_path
  content_md5            = data.archive_file.package.output_md5
}

# Read-only SAS so the Functions host can pull the package (run-from-package).
data "azurerm_storage_account_sas" "package" {
  connection_string = azurerm_storage_account.this.primary_connection_string
  https_only        = true
  signed_version    = "2021-06-08"

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  # Static window to avoid perpetual plan diffs; long-lived read-only package SAS.
  start  = "2024-01-01T00:00:00Z"
  expiry = "2099-01-01T00:00:00Z"

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

# --- Function App -------------------------------------------------------------

resource "azurerm_service_plan" "this" {
  name                = local.service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  # Windows: PowerShell Functions are supported on Windows Consumption (Y1).
  os_type  = "Windows"
  sku_name = "Y1"
  tags     = var.tags
}

resource "azurerm_windows_function_app" "this" {
  name                       = var.function_app_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.this.id
  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key
  https_only                 = true
  tags                       = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      powershell_core_version = "7.4"
    }
  }

  app_settings = local.app_settings

  lifecycle {
    ignore_changes = [
      # The Functions host manages the content share connection string.
      app_settings["WEBSITE_CONTENTAZUREFILECONNECTIONSTRING"],
      app_settings["WEBSITE_CONTENTSHARE"],
    ]
  }
}

# --- Least-privilege RBAC scoped to the single Application Gateway -------------

resource "azurerm_role_definition" "reconciler" {
  name        = local.role_definition_name
  scope       = var.application_gateway_id
  description = "Read/write the ledger trusted-root certificate on this Application Gateway."

  permissions {
    actions = [
      "Microsoft.Network/applicationGateways/read",
      "Microsoft.Network/applicationGateways/write",
      "Microsoft.Network/applicationGateways/backendHealth/action",
    ]
    not_actions = []
  }

  assignable_scopes = [var.application_gateway_id]
}

resource "azurerm_role_assignment" "reconciler" {
  scope              = var.application_gateway_id
  role_definition_id = azurerm_role_definition.reconciler.role_definition_resource_id
  principal_id       = azurerm_windows_function_app.this.identity[0].principal_id
}

# --- Immediate reaction: UnhealthyHostCount alert -> function HTTP trigger -----

data "azurerm_function_app_host_keys" "this" {
  count = var.alert_enabled ? 1 : 0

  name                = azurerm_windows_function_app.this.name
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_windows_function_app.this]
}

resource "azurerm_monitor_action_group" "this" {
  count = var.alert_enabled ? 1 : 0

  name                = "${var.function_app_name}-ag"
  resource_group_name = var.resource_group_name
  # Action group short_name must be ≤12 alphanumeric chars.
  short_name = substr(replace(replace(lower(var.function_app_name), "-", ""), ".", ""), 0, 12)
  location            = "global"
  tags                = var.tags

  azure_function_receiver {
    name                     = "reconcile"
    function_app_resource_id = azurerm_windows_function_app.this.id
    function_name            = "ReconcileHttp"
    http_trigger_url         = "https://${azurerm_windows_function_app.this.default_hostname}/api/ReconcileHttp?code=${data.azurerm_function_app_host_keys.this[0].default_function_key}"
    use_common_alert_schema  = true
  }
}

resource "azurerm_monitor_metric_alert" "ledger_backend_unhealthy" {
  count = var.alert_enabled ? 1 : 0

  name                = "${var.application_gateway_name}-ledger-cert-rotation"
  resource_group_name = var.resource_group_name
  scopes              = [var.application_gateway_id]
  description         = "Ledger backend unhealthy on ${var.application_gateway_name}; triggers immediate trusted-root cert reconcile."

  severity      = var.alert_severity
  enabled       = true
  auto_mitigate = true
  frequency     = var.alert_frequency
  window_size   = var.alert_window_size

  criteria {
    aggregation      = "Average"
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    operator         = "GreaterThan"
    threshold        = 0

    dimension {
      name     = "BackendSettingsPool"
      operator = "Include"
      values   = [var.ledger_backend_http_settings_name]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.this[0].id
  }
}
