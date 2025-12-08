# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# IMPORTANT: This data source ALWAYS reads the certificate from Key Vault during Terraform operations.
# It cannot use cached state - it must fetch fresh certificate data to configure the ledger.
#
# Network access: With public_network_access_enabled = true in the first deployment,
# this data source can read the certificate from any location.
data "azurerm_key_vault_certificate" "member" {
  name         = var.certificate_name
  key_vault_id = var.key_vault_id
}

data "external" "cert_pem" {
  program = ["bash", "-c", <<-EOT
    echo '${data.azurerm_key_vault_certificate.member.certificate_data}' | xxd -r -p | openssl x509 -inform DER -outform PEM | jq -Rs '{pem: .}'
  EOT
  ]
}

locals {
  pem_certificate = data.external.cert_pem.result.pem
}

resource "azurerm_confidential_ledger" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  ledger_type         = var.ledger_type
  tags                = var.tags

  azuread_based_service_principal {
    tenant_id        = var.azuread_based_service_principal_tenant_id
    principal_id     = var.azuread_based_service_principal_principal_id
    ledger_role_name = "Administrator"
  }

  certificate_based_security_principal {
    ledger_role_name = "Administrator"
    pem_public_key   = local.pem_certificate
  }

  lifecycle {
    # Ignore changes to azuread_based_service_principal blocks to preserve
    # principals that are automatically added by Azure or managed outside of Terraform
    ignore_changes = [azuread_based_service_principal]
  }
}

# Obtain the ledger's TLS certificate from the identity service endpoint
data "http" "ledger_identity" {
  url = "https://identity.confidential-ledger.core.azure.com/ledgerIdentity/${azurerm_confidential_ledger.this.name}"

  depends_on = [azurerm_confidential_ledger.this]
}

locals {
  ledger_identity_json   = jsondecode(data.http.ledger_identity.response_body)
  ledger_tls_certificate = local.ledger_identity_json.ledgerTlsCertificate
}

