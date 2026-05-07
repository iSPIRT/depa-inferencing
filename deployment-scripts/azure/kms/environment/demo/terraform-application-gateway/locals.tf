# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

locals {
  environment  = "prod"
  operator     = "tf"
  region       = "centralindia"
  region_short = "cin"

  subscription_id = "<your_subscription_id>"
  tenant_id       = "<your_tenant_id>"

  resource_group_name = "depa-inferencing-kms-${local.environment}-${local.region_short}-rg"
  # Key Vault name must match Phase 1 for this environment (see README: prod uses depa-inferencing-<region_short>-kv).
  key_vault_name           = "depa-inferencing-${local.region_short}-kv"
  virtual_network_name     = "depa-inferencing-kms-${local.environment}-${local.region_short}-vnet"
  application_gateway_name = "depa-inferencing-kms-${local.environment}-${local.region_short}-agw"
  managed_identity_name    = "depa-inferencing-kms-${local.region_short}-mi"
  ledger_name              = "depa-inferencing-kms-${local.environment}-${local.region_short}"

  ledger_private_link_service_alias = "<your-private-link-service-alias>"

  ssl_certificate_name                                    = "depa-inferencing-kms-${local.environment}-${local.region_short}-frontend-cert"
  diagnostics_log_analytics_workspace_name                = "<your_log_analytics_workspace_name>"
  diagnostics_log_analytics_workspace_resource_group_name = "<your_log_analytics_workspace_resource_group>"
  allowed_hostname                                        = "<your_gateway_public_hostname>"

  vm_vnet_resource_group_name = "depa-inferencing-prod"
  vm_vnet_name                = "vnet-depainf-cicd"
  vm_subnet_name              = "snet-depainf-cicd"

  ci_principal_id = "<your_ci_principal_object_id>"

  extra_tags = {
    Owner = "ispirt"
  }

  # Default 2 instances; set 1 for cost savings in non-prod
  application_gateway_capacity     = 2
  # Leave empty to use default ${application_gateway_name}-pip; else set to an existing PIP resource ID.
  application_gateway_public_ip_id = ""

  gateway_monitor_unhealthy_alert_enabled     = false
  gateway_monitor_alert_email_addresses       = {}
  gateway_monitor_action_group_name           = ""
  gateway_monitor_metric_alert_name           = ""
  gateway_monitor_action_group_short_name     = ""
  gateway_monitor_unhealthy_alert_description = ""
  gateway_monitor_additional_action_group_ids = []
  gateway_ledger_backend_http_settings_name   = ""
  gateway_monitor_unhealthy_alert_severity    = 2
  gateway_monitor_alert_frequency             = "PT1M"
  gateway_monitor_alert_window_size           = "PT5M"
}
