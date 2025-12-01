# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

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

