# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# This deployment sets up private endpoints for the Key Vault.
# It discovers existing resources created by the main KMS deployment.

module "key_vault_networking" {
  source = "../../../services/key_vault_networking"

  name                           = local.key_vault_name
  resource_group_name            = local.resource_group_name
  location                       = data.azurerm_resource_group.kms.location
  key_vault_id                   = data.azurerm_key_vault.kms.id
  private_endpoint_subnet_id     = data.azurerm_subnet.private_endpoint.id
  virtual_network_id             = data.azurerm_virtual_network.kms.id
  additional_virtual_network_ids = local.additional_virtual_network_ids
  tags                           = local.extra_tags
}

# Disable public network access on Key Vault after private endpoint is configured
# This resource updates the existing Key Vault created in the first deployment.
# The Key Vault must be imported into this state first using:
# terraform import azurerm_key_vault.disable_public_access /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{vault-name}
#
# Note: We use hardcoded values that match the first deployment since the data source
# doesn't expose all attributes. The lifecycle block ensures we only manage
# public_network_access_enabled and network_acls.
resource "azurerm_key_vault" "disable_public_access" {
  name                          = data.azurerm_key_vault.kms.name
  location                      = data.azurerm_key_vault.kms.location
  resource_group_name           = data.azurerm_key_vault.kms.resource_group_name
  tenant_id                     = data.azurerm_key_vault.kms.tenant_id
  sku_name                      = "premium" # Matches first deployment
  soft_delete_retention_days    = 7         # Matches first deployment
  purge_protection_enabled      = true      # Matches first deployment
  rbac_authorization_enabled    = true      # Matches first deployment
  public_network_access_enabled = false     # This is what we're changing
  tags                          = data.azurerm_key_vault.kms.tags

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny" # Changed from "Allow" in first deployment
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  lifecycle {
    # Only manage public_network_access_enabled and network_acls
    # Ignore all other properties that are managed by the first deployment
    ignore_changes = [
      name,
      location,
      resource_group_name,
      tenant_id,
      sku_name,
      soft_delete_retention_days,
      purge_protection_enabled,
      rbac_authorization_enabled,
      tags,
    ]
  }

  depends_on = [
    module.key_vault_networking,
  ]
}

# Ensure Application Gateway uses private endpoint for Key Vault access
# The Application Gateway's SSL certificate references Key Vault using key_vault_secret_id.
# Once the private DNS zone is linked to the VNet, the Application Gateway will automatically
# resolve Key Vault DNS to the private endpoint IP address.
#
# Note: The Application Gateway's key_vault_secret_id uses the format:
# https://{vault-name}.vault.azure.net/secrets/{secret-name}
# Azure's DNS resolution within the VNet will automatically use the private endpoint
# when the private DNS zone (privatelink.vaultcore.azure.net) is linked to the VNet.
#
# This data source ensures the Application Gateway exists and will use the private endpoint
# once the private DNS zone link is established.
data "azurerm_application_gateway" "kms" {
  name                = local.application_gateway_name
  resource_group_name = local.resource_group_name

  depends_on = [
    module.key_vault_networking,
  ]
}

