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

# Grant the CI principal data-plane access so the renewal workflow can upload
# challenge blobs into $web via `az storage blob upload --auth-mode login`.
# Subscription-level Contributor is a control-plane role and does not include
# blob data access; the data-plane role must be granted explicitly.
resource "azurerm_role_assignment" "ci_blob_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.ci_principal_id
}

# Private DNS zone for the storage web endpoint (used by AppGW to fetch the
# static-website HTTP responses for /.well-known/acme-challenge/*).
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

# Private DNS zone for the storage blob endpoint (used by `az storage blob
# upload` from the renewal workflow — the static-website "web" subresource is
# read-only, so writes have to go through the blob data plane).
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${var.name}-blob-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
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

# Private endpoint for the blob data plane (writes go here).
resource "azurerm_private_endpoint" "blob" {
  name                = "${var.name}-blob-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name}-blob-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}

# Look up the NICs each private endpoint created so we can pin the A records.
data "azurerm_network_interface" "web_pe" {
  name                = split("/", azurerm_private_endpoint.web.network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.web.network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.web,
  ]
}

data "azurerm_network_interface" "blob_pe" {
  name                = split("/", azurerm_private_endpoint.blob.network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.blob.network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.blob,
  ]
}

# Optional second pair of private endpoints in the CI runner's VNet so the
# renewal workflow can upload challenge blobs without going through the public
# endpoint. We need both `web` (so the runner can self-test) and `blob` (so the
# `az storage blob upload` data-plane call works).
resource "azurerm_private_endpoint" "web_vm" {
  count               = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                = "${var.name}-web-pe-vm"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.vm_private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name}-web-psc-vm"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["web"]
  }
}

resource "azurerm_private_endpoint" "blob_vm" {
  count               = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                = "${var.name}-blob-pe-vm"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.vm_private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name}-blob-psc-vm"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}

data "azurerm_network_interface" "web_vm_pe" {
  count               = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                = split("/", azurerm_private_endpoint.web_vm[0].network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.web_vm[0].network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.web_vm,
  ]
}

data "azurerm_network_interface" "blob_vm_pe" {
  count               = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                = split("/", azurerm_private_endpoint.blob_vm[0].network_interface[0].id)[8]
  resource_group_name = split("/", azurerm_private_endpoint.blob_vm[0].network_interface[0].id)[4]

  depends_on = [
    azurerm_private_endpoint.blob_vm,
  ]
}

# Link both privatelink zones to the runner VNet too so its DNS resolution
# returns the runner-side private endpoint IPs.
resource "azurerm_private_dns_zone_virtual_network_link" "web_vm" {
  count                 = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                  = "${var.name}-web-vnet-link-vm"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.web.name
  virtual_network_id    = var.vm_virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_vm" {
  count                 = var.vm_private_endpoint_subnet_id != "" ? 1 : 0
  name                  = "${var.name}-blob-vnet-link-vm"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = var.vm_virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# A records for the storage account in each privatelink zone. Azure CNAME-chains
# <account>.{web,blob}.core.windows.net -> <account>.privatelink.{web,blob}.core.windows.net
# which then resolves here to the private endpoint IPs. When a second VM-side
# PE exists, both IPs are listed (matches the pattern used by key_vault_networking).
resource "azurerm_private_dns_a_record" "web" {
  name                = azurerm_storage_account.this.name
  zone_name           = azurerm_private_dns_zone.web.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records = concat(
    [data.azurerm_network_interface.web_pe.ip_configuration[0].private_ip_address],
    var.vm_private_endpoint_subnet_id != "" ? [data.azurerm_network_interface.web_vm_pe[0].ip_configuration[0].private_ip_address] : []
  )
  tags = var.tags

  depends_on = [
    azurerm_private_endpoint.web,
    azurerm_private_dns_zone.web,
    data.azurerm_network_interface.web_pe,
  ]
}

resource "azurerm_private_dns_a_record" "blob" {
  name                = azurerm_storage_account.this.name
  zone_name           = azurerm_private_dns_zone.blob.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records = concat(
    [data.azurerm_network_interface.blob_pe.ip_configuration[0].private_ip_address],
    var.vm_private_endpoint_subnet_id != "" ? [data.azurerm_network_interface.blob_vm_pe[0].ip_configuration[0].private_ip_address] : []
  )
  tags = var.tags

  depends_on = [
    azurerm_private_endpoint.blob,
    azurerm_private_dns_zone.blob,
    data.azurerm_network_interface.blob_pe,
  ]
}
