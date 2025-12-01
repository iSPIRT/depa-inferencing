# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

data "azurerm_client_config" "current" {}

locals {
  admin_principal_ids = length(var.admin_principal_ids) > 0 ? var.admin_principal_ids : [data.azurerm_client_config.current.object_id]
}

resource "azurerm_key_vault" "this" {
  name                       = var.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  rbac_authorization_enabled = true
  tags                       = var.tags
}

resource "azurerm_role_assignment" "admin" {
  for_each             = toset(local.admin_principal_ids)
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "crypto_user" {
  count                = length(var.crypto_principal_ids)
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = var.crypto_principal_ids[count.index]
}

resource "azurerm_role_assignment" "crypto_officer" {
  count                = length(var.crypto_principal_ids)
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = var.crypto_principal_ids[count.index]
}

resource "azurerm_role_assignment" "certificates_officer" {
  count                = length(var.crypto_principal_ids)
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = var.crypto_principal_ids[count.index]
}

resource "azurerm_role_assignment" "secrets_user" {
  count                = length(var.secrets_user_principal_ids)
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.secrets_user_principal_ids[count.index]
}

resource "azurerm_key_vault_certificate" "member" {
  name         = var.certificate_name
  key_vault_id = azurerm_key_vault.this.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      curve      = "P-384"
      exportable = true
      key_type   = "EC"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 90
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      key_usage = [
        "digitalSignature",
      ]

      subject            = "CN=Member"
      validity_in_months = 12
    }
  }

  depends_on = [
    azurerm_role_assignment.admin,
  ]
}

