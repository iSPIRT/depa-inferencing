# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link Private DNS Zone to Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "${var.name}-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# Link Private DNS Zone to Additional Virtual Networks (for external VMs)
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault_additional" {
  for_each              = toset(var.additional_virtual_network_ids)
  name                  = "${var.name}-vnet-link-${substr(md5(each.value), 0, 8)}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = each.value
  registration_enabled  = false
  tags                  = var.tags
}

# Link Private DNS Zone to VM Virtual Network (if VM private endpoint is configured)
# This ensures DNS resolution works for the externally provisioned VM
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault_vm" {
  count                 = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                  = "${var.name}-vnet-link-vm"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = var.vm_virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault" {
  name                = "${var.name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name}-psc"
    private_connection_resource_id = var.key_vault_id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  # Note: The dependency on key_vault is enforced at the module level
  # via the key_vault_id variable reference, so no explicit depends_on needed here
}

# Data source to get the network interface for the private endpoint
data "azurerm_network_interface" "key_vault_pe" {
  name                = split("/", azurerm_private_endpoint.key_vault.network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.key_vault.network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.key_vault,
  ]
}

# Private Endpoint for externally provisioned VM (if configured)
resource "azurerm_private_endpoint" "key_vault_vm" {
  count                = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                 = "${var.name}-pe-vm"
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.vm_private_endpoint_subnet_id
  tags                 = var.tags

  private_service_connection {
    name                           = "${var.name}-psc-vm"
    private_connection_resource_id = var.key_vault_id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

# Data source to get the network interface for the VM private endpoint
data "azurerm_network_interface" "key_vault_vm_pe" {
  count               = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                = split("/", azurerm_private_endpoint.key_vault_vm[0].network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.key_vault_vm[0].network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.key_vault_vm,
  ]
}

# Private DNS A Record for Key Vault
# Includes IP addresses from all private endpoints (main + VM endpoint if configured)
resource "azurerm_private_dns_a_record" "key_vault" {
  name                = var.name
  zone_name           = azurerm_private_dns_zone.key_vault.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  # Combine IPs from main private endpoint and VM private endpoint (if configured)
  records = concat(
    [data.azurerm_network_interface.key_vault_pe.ip_configuration[0].private_ip_address],
    var.vm_private_endpoint_subnet_id != "" ? [data.azurerm_network_interface.key_vault_vm_pe[0].ip_configuration[0].private_ip_address] : []
  )
  tags = var.tags

  depends_on = [
    azurerm_private_endpoint.key_vault,
    azurerm_private_dns_zone.key_vault,
    data.azurerm_network_interface.key_vault_pe,
  ]
}

