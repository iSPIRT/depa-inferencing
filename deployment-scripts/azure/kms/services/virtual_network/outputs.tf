# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "id" {
  description = "Resource ID of the Virtual Network."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Name of the Virtual Network."
  value       = azurerm_virtual_network.this.name
}

output "gateway_subnet_id" {
  description = "Resource ID of the Application Gateway subnet."
  value       = azurerm_subnet.gateway.id
}

output "private_endpoint_subnet_id" {
  description = "Resource ID of the private endpoint subnet."
  value       = azurerm_subnet.private_endpoint.id
}

