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

locals {
  frontend_service_name = "offer"
  resource_group_name   = "${var.operator}-${var.environment}-${local.frontend_service_name}-${module.regions.location_short}-rg"
}

module "regions" {
  source       = "claranet/regions/azurerm"
  version      = "7.2.0"
  azure_region = var.region
}

module "networking" {
  source                = "../../services/networking"
  resource_group_name   = local.resource_group_name
  frontend_service_name = local.frontend_service_name
  operator              = var.operator
  environment           = var.environment
  region                = module.regions.location_cli
  region_short          = module.regions.location_short
}

module "aks" {
  source                = "../../services/aks"
  resource_group_name   = local.resource_group_name
  frontend_service_name = local.frontend_service_name
  operator              = var.operator
  environment           = var.environment
  region                = module.regions.location_cli
  region_short          = module.regions.location_short
}

module "app_gw" {
  source                = "../../services/app_gw"
  operator              = var.operator
  environment           = var.environment
  region                = module.regions.location_cli
  region_short          = module.regions.location_short
  resource_group_name   = local.resource_group_name
  appgw_public_ip       = module.networking.public_ip
  appgw_subnet_id       = module.networking.subnet_id
  frontend_service_name = local.frontend_service_name
  frontend_service_ip   = module.aks.frontend_service_ip
}

output "aks_spec" {
  value = module.aks.frontend_service_spec
}