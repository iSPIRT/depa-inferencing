# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

locals {
  create_kms_ledger_pe = var.existing_kms_ledger_private_ip == ""
  kms_ledger_a_record_ips = compact(concat(
    local.create_kms_ledger_pe ? [data.azurerm_network_interface.ledger_pe[0].ip_configuration[0].private_ip_address] : [var.existing_kms_ledger_private_ip],
    var.vm_private_endpoint_subnet_id != "" ? [data.azurerm_network_interface.ledger_vm_pe[0].ip_configuration[0].private_ip_address] : [],
  ))
}

# Private DNS Zone for Confidential Ledger
resource "azurerm_private_dns_zone" "ledger" {
  name                = "confidential-ledger.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "ledger" {
  name                  = "${var.name}-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.ledger.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "ledger_vm" {
  count                 = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                  = "${var.name}-vnet-link-vm"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.ledger.name
  virtual_network_id    = var.vm_virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# KMS-side PE (UAT / greenfield). Prod uses existing_kms_ledger_private_ip for kmspls PE instead.
resource "azurerm_private_endpoint" "ledger" {
  count               = local.create_kms_ledger_pe ? 1 : 0
  name                = "${var.name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                              = "${var.name}-psc"
    private_connection_resource_alias = var.private_link_service_alias
    is_manual_connection              = true
    request_message                   = "Private endpoint for Confidential Ledger"
  }
}

resource "azurerm_private_endpoint" "ledger_vm" {
  count               = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                = "${var.name}-pe-vm"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.vm_private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                              = "${var.name}-psc-vm"
    private_connection_resource_alias = var.private_link_service_alias
    is_manual_connection              = true
    request_message                   = "Private endpoint for Confidential Ledger (runner VM)"
  }
}

data "azurerm_network_interface" "ledger_pe" {
  count               = local.create_kms_ledger_pe ? 1 : 0
  name                = split("/", azurerm_private_endpoint.ledger[0].network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.ledger[0].network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.ledger,
  ]
}

data "azurerm_network_interface" "ledger_vm_pe" {
  count               = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                = split("/", azurerm_private_endpoint.ledger_vm[0].network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.ledger_vm[0].network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.ledger_vm,
  ]
}

resource "azurerm_private_dns_a_record" "ledger" {
  name                = var.name
  zone_name           = azurerm_private_dns_zone.ledger.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = local.kms_ledger_a_record_ips
  tags                = var.tags

  depends_on = [
    azurerm_private_dns_zone.ledger,
  ]
}
