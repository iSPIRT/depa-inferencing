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
  environment = "demo"
  operator    = "tf"

  # Please refer to https://github.com/claranet/terraform-azurerm-regions/blob/master/REGIONS.md for region codes. Check the "Region Deployments" section in https://github.com/microsoft/virtualnodesOnAzureContainerInstances for regions that support confidential pods.
  region = "northeurope"

  subscription_id = "<your_subscription_id>"
  tenant_id       = "<your_tenant_id>"
}

module "appgw" {
  source          = "../../../modules/appgw"
  environment     = local.environment
  operator        = local.operator
  region          = local.region
  subscription_id = local.subscription_id
  tenant_id       = local.tenant_id
}
