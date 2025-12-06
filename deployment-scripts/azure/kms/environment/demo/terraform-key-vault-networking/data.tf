# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# Discover existing resource group
data "azurerm_resource_group" "kms" {
  name = local.resource_group_name
}

# Discover existing Key Vault
data "azurerm_key_vault" "kms" {
  name                = local.key_vault_name
  resource_group_name = local.resource_group_name
}

# Discover existing Virtual Network
data "azurerm_virtual_network" "kms" {
  name                = local.virtual_network_name
  resource_group_name = local.resource_group_name
}

# Discover private endpoint subnet
# The subnet name follows the pattern: ${vnet_name}-private-endpoint-subnet
data "azurerm_subnet" "private_endpoint" {
  name                 = "${local.virtual_network_name}-private-endpoint-subnet"
  virtual_network_name = data.azurerm_virtual_network.kms.name
  resource_group_name  = local.resource_group_name
}

