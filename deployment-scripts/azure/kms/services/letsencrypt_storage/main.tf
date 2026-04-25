# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# Storage account that holds Let's Encrypt HTTP-01 challenge tokens.
# The account is private: public network access is disabled and access happens
# exclusively through a private endpoint in the KMS VNet. The Application
# Gateway reaches the static website endpoint over the same private endpoint
# via the privatelink.web.core.windows.net DNS zone.
resource "azurerm_storage_account" "this" {
  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  # Shared keys are kept enabled so the azurerm provider can poll the blob
  # data-plane during create (it does this via the account key, even when the
  # account is private). The keys are not usable from outside the VNet because
  # public network access is disabled; the renewal workflow itself authenticates
  # with AAD via `az --auth-mode login`, not the shared key.
  shared_access_key_enabled       = true
  default_to_oauth_authentication = true
  min_tls_version                 = "TLS1_2"
  tags                            = var.tags
}

# Enable static website hosting via the dedicated resource (the inline
# static_website block on azurerm_storage_account is deprecated in azurerm 4.x
# and removed in 5.0).
resource "azurerm_storage_account_static_website" "this" {
  storage_account_id = azurerm_storage_account.this.id
  index_document     = "index.html"
  error_404_document = "index.html"
}

# Private DNS zone for the storage web endpoint.
resource "azurerm_private_dns_zone" "web" {
  name                = "privatelink.web.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "web" {
  name                  = "${var.name}-web-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.web.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# Private endpoint for the static website (web) subresource.
resource "azurerm_private_endpoint" "web" {
  name                = "${var.name}-web-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name}-web-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["web"]
  }
}

# Look up the NIC the private endpoint created so we can pin the A record.
data "azurerm_network_interface" "web_pe" {
  name                = split("/", azurerm_private_endpoint.web.network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.web.network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.web,
  ]
}

# A record for the storage account in the privatelink zone. Azure CNAME-chains
# <account>.z<N>.web.core.windows.net -> <account>.privatelink.web.core.windows.net
# which then resolves here to the private endpoint IP.
resource "azurerm_private_dns_a_record" "web" {
  name                = azurerm_storage_account.this.name
  zone_name           = azurerm_private_dns_zone.web.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [data.azurerm_network_interface.web_pe.ip_configuration[0].private_ip_address]
  tags                = var.tags

  depends_on = [
    azurerm_private_endpoint.web,
    azurerm_private_dns_zone.web,
    data.azurerm_network_interface.web_pe,
  ]
}
