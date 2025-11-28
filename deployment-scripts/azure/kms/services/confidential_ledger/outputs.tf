# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "id" {
  description = "Resource ID of the Confidential Ledger."
  value       = azurerm_confidential_ledger.this.id
}

output "name" {
  description = "Name of the Confidential Ledger."
  value       = azurerm_confidential_ledger.this.name
}

output "identity_service_endpoint" {
  description = "Identity Service Endpoint for the Confidential Ledger."
  value       = azurerm_confidential_ledger.this.identity_service_endpoint
}

output "ledger_endpoint" {
  description = "Ledger Endpoint for the Confidential Ledger."
  value       = azurerm_confidential_ledger.this.ledger_endpoint
}

output "ledger_tls_certificate" {
  description = "TLS certificate of the Confidential Ledger in PEM format."
  value       = local.ledger_tls_certificate
  sensitive   = false
}

