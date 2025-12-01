# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "id" {
  description = "Resource ID of the Application Gateway."
  value       = azurerm_application_gateway.this.id
}

output "name" {
  description = "Name of the Application Gateway."
  value       = azurerm_application_gateway.this.name
}

output "public_ip_address" {
  description = "Public IP address of the Application Gateway."
  value       = azurerm_public_ip.gateway.ip_address
}

output "public_ip_id" {
  description = "Resource ID of the public IP address."
  value       = azurerm_public_ip.gateway.id
}

output "fqdn" {
  description = "FQDN of the Application Gateway."
  value       = azurerm_public_ip.gateway.fqdn
}

output "endpoint" {
  description = "Endpoint URL of the Application Gateway (using FQDN if available, otherwise IP address)."
  value = coalesce(
    azurerm_public_ip.gateway.fqdn != null && azurerm_public_ip.gateway.fqdn != "" ? "http://${azurerm_public_ip.gateway.fqdn}" : null,
    "http://${azurerm_public_ip.gateway.ip_address}"
  )
}

