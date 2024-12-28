# Portions Copyright (c) Microsoft Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "azurerm_client_config" "current" {}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

resource "azurerm_key_vault" "keyvault" {
  name                      = "${var.operator}-${var.environment}-${var.frontend_service_name}-${var.region_short}-akv"
  location                  = var.region
  resource_group_name       = var.resource_group_name
  sku_name                  = "standard"
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true
}

resource "azurerm_role_assignment" "officer" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Certificates Officer"
  scope                = azurerm_key_vault.keyvault.id
}

resource "azurerm_role_assignment" "user" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Certificate User"
  scope                = azurerm_key_vault.keyvault.id
}

resource "azurerm_user_assigned_identity" "identity" {
  name                = "appgw-key-vault-user-identity"
  location            = var.region
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "managed_identity_user" {
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
  role_definition_name = "Key Vault Certificate User"
  scope                = azurerm_key_vault.keyvault.id
}

resource "azurerm_role_assignment" "managed_identity_secrets_user" {
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.keyvault.id
}

resource "random_uuid" "cert_id" {
}

resource "azurerm_key_vault_certificate" "cert" {
  name         = "generated-cert-${random_uuid.cert_id.result}"
  key_vault_id = azurerm_key_vault.keyvault.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject_alternative_names {
        dns_names = ["test.buyer.com"]
      }

      subject            = "CN=hello-world"
      validity_in_months = 12
    }
  }
}
