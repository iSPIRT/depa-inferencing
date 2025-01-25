# Portions Copyright (c) Microsoft Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Azure Storage Accounts requires a globally unique names
## https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
## Create a File Storage Account
resource "azurerm_storage_account" "this" {
  name                            = "${var.operator}${var.environment}${substr(var.frontend_service_name, 0, 3)}${var.region_short}storage"
  resource_group_name             = var.resource_group_name
  location                        = var.region
  account_tier                    = "Standard"
  account_replication_type        = "LRS"

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

resource "azurerm_storage_share" "this" {
  name                 = "fslogix"
  storage_account_name = azurerm_storage_account.this.name
  quota                = 5120
}

resource "azurerm_storage_share_directory" "deltas" {
  name             = "deltas"
  storage_share_id = azurerm_storage_share.this.id
}

resource "azurerm_storage_share_directory" "realtime" {
  name             = "realtime"
  storage_share_id = azurerm_storage_share.this.id
}

# Create Private Endpoint for the Storage Account
resource "azurerm_private_endpoint" "storage_private_endpoint" {
  name                = "storage_private_endpoint"
  location            = var.region
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "storage_private_connection"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["file"] # You can specify 'blob', 'file', 'table', etc.
    is_manual_connection           = false
  }
}
