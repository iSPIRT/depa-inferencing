# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.this.name
}

output "uri" {
  description = "Vault URI for accessing secrets/keys."
  value       = azurerm_key_vault.this.vault_uri
}

output "certificate_secret_id" {
  description = "Secret ID of the certificate stored in Key Vault."
  value       = azurerm_key_vault_certificate.member.secret_id
}


