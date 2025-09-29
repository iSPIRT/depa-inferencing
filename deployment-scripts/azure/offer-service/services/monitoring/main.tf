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

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "app_insights_ws" {
  name                = "${var.operator}-${var.environment}-${var.frontend_service_name}-${var.region_short}-app-insights-ws"
  location            = var.region
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "app_insights" {
  name                = "${var.operator}-${var.environment}-${var.frontend_service_name}-${var.region_short}-app-insights"
  location            = var.region
  resource_group_name = var.resource_group_name
  application_type    = "other"
  workspace_id        = azurerm_log_analytics_workspace.app_insights_ws.id
  depends_on          = [azurerm_log_analytics_workspace.app_insights_ws]
}
