# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

## Azure Storage Accounts requires a globally unique names
## https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
## Create a Storage Account for Confidential Ledger backup
resource "azurerm_storage_account" "this" {
  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = var.account_tier
  account_replication_type        = var.account_replication_type
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = var.tags
}

## Create a File Share for storing ledger backups
resource "azurerm_storage_share" "ledger_backup" {
  name               = var.file_share_name
  storage_account_id = azurerm_storage_account.this.id
  quota              = var.file_share_quota_gb
}

## Grant the managed identity Storage File Data SMB Share Contributor role for the file share
resource "azurerm_role_assignment" "storage_file_share_contributor" {
  scope                            = azurerm_storage_share.ledger_backup.id
  role_definition_name             = "Storage File Data SMB Share Contributor"
  principal_id                     = var.managed_identity_principal_id
  skip_service_principal_aad_check = true

  depends_on = [
    azurerm_storage_account.this,
    azurerm_storage_share.ledger_backup,
  ]
}

## Grant the managed identity Storage Blob Data Contributor role for the storage account (for additional backup operations)
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                            = azurerm_storage_account.this.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = var.managed_identity_principal_id
  skip_service_principal_aad_check = true

  depends_on = [
    azurerm_storage_account.this,
  ]
}

