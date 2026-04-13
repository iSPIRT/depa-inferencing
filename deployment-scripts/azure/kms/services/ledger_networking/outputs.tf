# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "private_endpoint_id" {
  description = "Resource ID of the private endpoint for the Confidential Ledger."
  value       = azurerm_private_endpoint.ledger.id
}

output "private_dns_zone_id" {
  description = "Resource ID of the private DNS zone for the Confidential Ledger."
  value       = azurerm_private_dns_zone.ledger.id
}

output "private_dns_zone_name" {
  description = "Name of the private DNS zone for the Confidential Ledger."
  value       = azurerm_private_dns_zone.ledger.name
}

output "ledger_private_fqdn" {
  description = "Private FQDN for the Confidential Ledger (resolves to the private endpoint IP within the VNet)."
  value       = "${var.name}.${azurerm_private_dns_zone.ledger.name}"
}
