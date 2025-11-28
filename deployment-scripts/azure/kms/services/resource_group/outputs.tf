# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "id" {
  description = "Resource ID of the resource group."
  value       = azurerm_resource_group.this.id
}

output "name" {
  description = "Name of the created resource group."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure region where the resource group resides."
  value       = azurerm_resource_group.this.location
}

