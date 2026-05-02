# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# Private DNS Zone for Confidential Ledger
# Overrides public DNS so the ledger's FQDN resolves to the private endpoint IP within the VNet.
resource "azurerm_private_dns_zone" "ledger" {
  name                = "confidential-ledger.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link Private DNS Zone to Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "ledger" {
  name                  = "${var.name}-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.ledger.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# Link Private DNS Zone to the runner VM's Virtual Network so the runner resolves
# the ledger FQDN to the runner-side private endpoint IP.
resource "azurerm_private_dns_zone_virtual_network_link" "ledger_vm" {
  count                 = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                  = "${var.name}-vnet-link-vm"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.ledger.name
  virtual_network_id    = var.vm_virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# Private Endpoint connecting to the Ledger's Private Link Service
resource "azurerm_private_endpoint" "ledger" {
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

# Optional second private endpoint in the CI runner's VNet so the runner can
# reach the ledger over Private Link without going through the public FQDN.
# This connection also requires manual approval on the PLS, just like the
# KMS-side endpoint.
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

# Data source to get the network interface for the private endpoint
data "azurerm_network_interface" "ledger_pe" {
  name                = split("/", azurerm_private_endpoint.ledger.network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.ledger.network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.ledger,
  ]
}

# Data source for the runner-side PE NIC (only when the VM-side PE exists).
data "azurerm_network_interface" "ledger_vm_pe" {
  count               = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                = split("/", azurerm_private_endpoint.ledger_vm[0].network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.ledger_vm[0].network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.ledger_vm,
  ]
}

# Private DNS A Record for Confidential Ledger
# Maps the ledger name to the private endpoint IP so that
# {name}.confidential-ledger.azure.com resolves to the PE IP within the VNet.
# When a runner-side PE exists, both IPs are listed (matches the pattern used
# by key_vault_networking).
resource "azurerm_private_dns_a_record" "ledger" {
  name                = var.name
  zone_name           = azurerm_private_dns_zone.ledger.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records = concat(
    [data.azurerm_network_interface.ledger_pe.ip_configuration[0].private_ip_address],
    var.vm_private_endpoint_subnet_id != "" ? [data.azurerm_network_interface.ledger_vm_pe[0].ip_configuration[0].private_ip_address] : []
  )
  tags = var.tags

  depends_on = [
    azurerm_private_endpoint.ledger,
    azurerm_private_dns_zone.ledger,
    data.azurerm_network_interface.ledger_pe,
  ]
}
