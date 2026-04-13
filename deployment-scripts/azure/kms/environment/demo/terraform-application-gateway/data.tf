# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# Discover existing resources created by the Phase 1 (terraform/) deployment.

data "azurerm_resource_group" "kms" {
  name = local.resource_group_name
}

data "azurerm_virtual_network" "kms" {
  name                = local.virtual_network_name
  resource_group_name = local.resource_group_name
}

# Gateway subnet for the Application Gateway
data "azurerm_subnet" "gateway" {
  name                 = "${local.virtual_network_name}-gateway-subnet"
  virtual_network_name = data.azurerm_virtual_network.kms.name
  resource_group_name  = local.resource_group_name
}

# Private endpoint subnet for the Ledger private endpoint
data "azurerm_subnet" "private_endpoint" {
  name                 = "${local.virtual_network_name}-private-endpoint-subnet"
  virtual_network_name = data.azurerm_virtual_network.kms.name
  resource_group_name  = local.resource_group_name
}

data "azurerm_key_vault" "kms" {
  name                = local.key_vault_name
  resource_group_name = local.resource_group_name
}

data "azurerm_user_assigned_identity" "kms" {
  name                = local.managed_identity_name
  resource_group_name = local.resource_group_name
}

# Fetch the Confidential Ledger's TLS certificate from Azure's identity service.
# This is the same mechanism used by services/confidential_ledger/main.tf.
data "http" "ledger_identity" {
  url = "https://identity.confidential-ledger.core.azure.com/ledgerIdentity/${local.ledger_name}"
}
