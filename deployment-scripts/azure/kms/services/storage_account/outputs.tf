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

output "file_share_name" {
  description = "Name of the file share for ledger backups."
  value       = azurerm_storage_share.ledger_backup.name
}

output "file_share_id" {
  description = "Resource ID of the file share."
  value       = azurerm_storage_share.ledger_backup.id
}

output "file_share_url" {
  description = "URL of the file share for accessing backups."
  value       = "${azurerm_storage_account.this.primary_file_endpoint}${azurerm_storage_share.ledger_backup.name}"
}

