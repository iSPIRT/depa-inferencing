# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

data "azurerm_resource_group" "kms" {
  name = local.resource_group_name
}

data "azurerm_virtual_network" "kms" {
  name                = local.virtual_network_name
  resource_group_name = local.resource_group_name
}

data "azurerm_subnet" "private_endpoint" {
  name                 = "${local.virtual_network_name}-private-endpoint-subnet"
  virtual_network_name = data.azurerm_virtual_network.kms.name
  resource_group_name  = local.resource_group_name
}

data "azurerm_virtual_network" "vm" {
  name                = local.vm_vnet_name
  resource_group_name = local.vm_vnet_resource_group_name
}

data "azurerm_subnet" "vm_private_endpoint" {
  name                 = local.vm_subnet_name
  virtual_network_name = data.azurerm_virtual_network.vm.name
  resource_group_name  = local.vm_vnet_resource_group_name
}
