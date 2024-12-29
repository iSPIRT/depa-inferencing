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

################ Common Setup ################

locals {
  frontend_service_name = "offer"
}

module "regions" {
  source       = "claranet/regions/azurerm"
  version      = "7.2.0"
  azure_region = var.region
}

module "resource_group" {
  source                = "../../services/resource_group"
  frontend_service_name = local.frontend_service_name
  operator              = var.operator
  environment           = var.environment
  region                = module.regions.location_cli
  region_short          = module.regions.location_short
}

module "networking" {
  source                = "../../services/networking"
  resource_group_name   = module.resource_group.name
  frontend_service_name = local.frontend_service_name
  operator              = var.operator
  environment           = var.environment
  region                = module.regions.location_cli
  region_short          = module.regions.location_short
}

module "egress_proxy" {
  source 		= "../../services/egress_proxy"
  resource_group_name   = module.resource_group.name
  operator		= var.operator
  environment           = var.environment
  frontend_service_name = local.frontend_service_name
  region                = module.regions.location_cli
  region_short          = module.regions.location_short
  aks_vnet_name	        = module.networking.vnet_name
  aks_vnet_id           = module.networking.vnet_id
}

module "aks" {
  source                = "../../services/aks"
  resource_group_id     = module.resource_group.id
  resource_group_name   = module.resource_group.name
  frontend_service_name = local.frontend_service_name
  operator              = var.operator
  environment           = var.environment
  region                = module.regions.location_cli
  subnet_id             = module.networking.aks_subnet_id
  virtual_network_id    = module.networking.vnet_id
  region_short          = module.regions.location_short
  node_pool_settings    = var.node_pool_settings
}

module "route_table" {
  source               = "../../services/route_table"
  resource_group_name   = module.resource_group.name
  operator		= var.operator
  environment           = var.environment
  region                = module.regions.location_cli
  https_proxy_ip 	= module.egress_proxy.egress_proxy_ip_address
  aks_subnet_id         = module.networking.aks_subnet_id
  cg_subnet_id          = module.networking.cg_subnet_id
}

module "external_dns" {
  source                     = "../../services/external_dns"
  resource_group_id          = module.resource_group.id
  resource_group_name        = module.resource_group.name
  region                     = var.region
  vnet_id                    = module.networking.vnet_id
  vnet_name                  = module.networking.vnet_name
  private_domain_name        = var.private_domain_name
  aks_cluster_name           = module.aks.name
  aks_oidc_issuer_url        = module.aks.oidc_issuer_url
  kubernetes_namespace       = var.externaldns_kubernetes_namespace
  kubernetes_service_account = var.externaldns_kubernetes_service_account
  tenant_id                  = var.tenant_id
  subscription_id            = var.subscription_id
}

module "virtual_node" {
  source               = "../../services/virtual_node"
  kubernetes_namespace = "vn2"
  aks_cluster_name     = module.aks.name
  resource_group_name  = module.resource_group.name
  containers           = var.containers
}

module "app" {
  source                            = "../../services/app"
  side                              = local.frontend_service_name
  kubernetes_namespace              = "default"
  aks_cluster_name                  = module.aks.name
  resource_group_name               = module.resource_group.name
  virtual_node_identity_id          = module.aks.virtual_node_identity_id
  containers                        = var.containers
  key_vault_name                    = ""
  sfe_certificate_name              = ""
  global_runtime_flags              = var.global_runtime_flags
  virtual_node_identity_id_override = var.custom_aks_workload_identity_id
  instrumentation_key               = module.app_insights.instrumentation_key
  storage_account_name              = module.storage_account.name
  file_share_name                   = module.storage_account.file_share
  storage_account_access_key        = module.storage_account.access_key
}

module "app_insights" {
  source                = "../../services/monitoring"
  resource_group_id     = module.resource_group.id
  resource_group_name   = module.resource_group.name
  frontend_service_name = local.frontend_service_name
  operator              = var.operator
  environment           = var.environment
  region                = module.regions.location_cli
  region_short          = module.regions.location_short
  subscription_id       = var.subscription_id
}

module "storage_account" {
  source                = "../../services/storage_account"
  operator              = var.operator
  environment           = var.environment
  frontend_service_name = local.frontend_service_name
  region                = module.regions.location_cli
  region_short          = module.regions.location_short
  resource_group_name   = module.resource_group.name
}
