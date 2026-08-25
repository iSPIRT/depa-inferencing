# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.
#
# Standalone deployment of the ledger certificate reconciler.
#
# This root has its OWN Terraform state and does not manage any phase-3 resource.
# It only reads the existing Application Gateway (data source) and creates the
# additive reconciler resources (Function App + identity + AGW-scoped role +
# alert). It cannot modify the gateway definition, backend pools, listeners,
# WAF, or any other KMS resource.

data "azurerm_client_config" "current" {}

# Existing Application Gateway created by phase-3 (terraform-application-gateway).
data "azurerm_application_gateway" "agw" {
  name                = local.application_gateway_name
  resource_group_name = local.resource_group_name
}

module "ledger_cert_reconciler" {
  source = "../../../services/ledger_cert_reconciler"

  resource_group_name = local.resource_group_name
  location            = data.azurerm_application_gateway.agw.location
  subscription_id     = data.azurerm_client_config.current.subscription_id

  application_gateway_id        = data.azurerm_application_gateway.agw.id
  application_gateway_name      = local.application_gateway_name
  ledger_name                   = local.ledger_name
  trusted_root_certificate_name = local.trusted_root_certificate_name

  storage_account_name = local.storage_account_name
  function_app_name    = local.function_app_name
  reconcile_schedule   = local.reconcile_schedule

  tags = local.tags
}
