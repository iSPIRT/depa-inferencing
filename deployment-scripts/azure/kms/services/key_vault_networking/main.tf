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

# Private DNS A Record for Key Vault
resource "azurerm_private_dns_a_record" "key_vault" {
  name                = var.name
  zone_name           = azurerm_private_dns_zone.key_vault.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [data.azurerm_network_interface.key_vault_pe.ip_configuration[0].private_ip_address]
  tags                = var.tags

  depends_on = [
    azurerm_private_endpoint.key_vault,
    azurerm_private_dns_zone.key_vault,
    data.azurerm_network_interface.key_vault_pe,
  ]
}

