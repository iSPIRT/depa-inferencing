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

output "ledger_vm_private_endpoint_id" {
  description = "Resource ID of the runner-side Ledger private endpoint (empty if not configured)."
  value       = module.ledger_networking.vm_private_endpoint_id
}

output "ledger_private_dns_zone_id" {
  description = "Resource ID of the private DNS zone for the Confidential Ledger."
  value       = module.ledger_networking.private_dns_zone_id
}

output "ledger_private_fqdn" {
  description = "Private FQDN for the Confidential Ledger."
  value       = module.ledger_networking.ledger_private_fqdn
}

output "acme_challenge_storage_account_name" {
  description = "Storage account that hosts ACME HTTP-01 challenge tokens for the frontend cert renewal workflow."
  value       = module.letsencrypt_storage.storage_account_name
}

output "acme_challenge_backend_fqdn" {
  description = "Static website FQDN used as the App Gateway backend for /.well-known/acme-challenge/*."
  value       = module.letsencrypt_storage.web_endpoint_host
}
