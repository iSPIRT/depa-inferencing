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

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.operator}-${var.environment}-${var.frontend_service_name}-${var.region_short}-appgw-vnet"
  location            = var.region
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.4.1.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "public-ip"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
}

data "azurerm_virtual_network" "aks_vnet" {
  name                = "${var.operator}-${var.environment}-${var.frontend_service_name}-${var.region_short}-vnet"
  resource_group_name = var.resource_group_name
}