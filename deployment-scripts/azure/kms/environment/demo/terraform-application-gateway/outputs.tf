# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "application_gateway_id" {
  description = "Resource ID of the Application Gateway."
  value       = module.application_gateway.id
}

output "application_gateway_endpoint" {
  description = "Endpoint URL of the Application Gateway."
  value       = module.application_gateway.endpoint
}

output "application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway."
  value       = module.application_gateway.public_ip_address
}

output "ledger_private_endpoint_id" {
  description = "Resource ID of the Ledger private endpoint."
  value       = module.ledger_networking.private_endpoint_id
}

output "ledger_private_dns_zone_id" {
  description = "Resource ID of the private DNS zone for the Confidential Ledger."
  value       = module.ledger_networking.private_dns_zone_id
}

output "ledger_private_fqdn" {
  description = "Private FQDN for the Confidential Ledger."
  value       = module.ledger_networking.ledger_private_fqdn
}
