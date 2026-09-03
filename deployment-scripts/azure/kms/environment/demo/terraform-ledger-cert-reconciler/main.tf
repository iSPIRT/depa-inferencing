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

data "azurerm_resource_group" "kms" {
  name = local.resource_group_name
}

# Existing Application Gateway created by phase-3 (terraform-application-gateway).
data "azurerm_application_gateway" "agw" {
  name                = local.application_gateway_name
  resource_group_name = local.resource_group_name
}

locals {
  # Everything the gateway definition points at. Updating the trusted root
  # certificate re-PUTs the whole gateway, and ARM re-checks these links, so the
  # function identity needs join/assign on each one.
  linked_resource_ids = merge(
    {
      for i, c in data.azurerm_application_gateway.agw.gateway_ip_configuration :
      "subnet-${i}" => c.subnet_id if c.subnet_id != null && c.subnet_id != ""
    },
    {
      for i, c in data.azurerm_application_gateway.agw.frontend_ip_configuration :
      "public-ip-${i}" => c.public_ip_address_id if c.public_ip_address_id != null && c.public_ip_address_id != ""
    },
    {
      for i, id in try(data.azurerm_application_gateway.agw.identity[0].identity_ids, []) :
      "user-assigned-identity-${i}" => id
    },
    data.azurerm_application_gateway.agw.firewall_policy_id != "" ? {
      "waf-policy" = data.azurerm_application_gateway.agw.firewall_policy_id
    } : {}
  )
}

module "ledger_cert_reconciler" {
  source = "../../../services/ledger_cert_reconciler"

  resource_group_name = local.resource_group_name
  resource_group_id   = data.azurerm_resource_group.kms.id
  location            = data.azurerm_application_gateway.agw.location
  subscription_id     = data.azurerm_client_config.current.subscription_id

  application_gateway_id        = data.azurerm_application_gateway.agw.id
  application_gateway_name      = local.application_gateway_name
  ledger_name                   = local.ledger_name
  trusted_root_certificate_name = local.trusted_root_certificate_name
  linked_resource_ids           = local.linked_resource_ids

  storage_account_name = local.storage_account_name
  function_app_name    = local.function_app_name
  reconcile_schedule   = local.reconcile_schedule

  tags = local.tags
}
