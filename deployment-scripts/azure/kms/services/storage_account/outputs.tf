# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

output "id" {
  description = "Resource ID of the storage account."
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Name of the storage account."
  value       = azurerm_storage_account.this.name
}

output "primary_endpoint" {
  description = "The primary endpoint URL for the storage account."
  value       = azurerm_storage_account.this.primary_file_endpoint
}

