# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

resource "azurerm_network_ddos_protection_plan" "this" {
  name                = "${var.name}-ddos-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.this.id
    enable = true
  }
}

resource "azurerm_subnet" "gateway" {
  name                 = "${var.name}-gateway-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_address_prefixes
}

resource "azurerm_subnet" "private_endpoint" {
  name                 = "${var.name}-private-endpoint-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.private_endpoint_subnet_address_prefixes
}

resource "azurerm_subnet" "kms_private_link" {
  name                 = "KmsPrivateLinkSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.kms_private_link_subnet_address_prefixes
}

