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

resource "azurerm_web_application_firewall_policy" "policy" {
  name                = "waf-policy"
  location            = var.region
  resource_group_name = var.resource_group_name
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_application_gateway" "appgw" {
  name                = "${var.operator}-${var.environment}-${var.frontend_service_name}-${var.region_short}-appgw"
  location            = var.region
  resource_group_name = var.resource_group_name

  identity {
    type         = "UserAssigned"
    identity_ids = [ var.user_identity_id ]
  }

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 15
  }

  # A backend pool routes request to backend servers, which serve the request.
  # Can create different backend pools for different types of requests
  backend_address_pool {
    name = "appgw-backend-address-pool"
    ip_addresses = [ var.frontend_service_ip ]
  }

  backend_http_settings {
    name                  = "appgw-backend-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    request_timeout       = 30
    protocol              = "Http"
    port                  = 50051
  }

  request_routing_rule {
    name                       = "appgw-request-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-http-listener"
    backend_address_pool_name  = "appgw-backend-address-pool"
    backend_http_settings_name = "appgw-backend-http-settings"
    priority                   = 1
  }

  http_listener {
    name                           = "appgw-http-listener"
    frontend_port_name             = "appgw-frontend-port"
    frontend_ip_configuration_name = "appgw-frontend-ip-configuration"
    protocol                       = "Https"
    ssl_certificate_name           = "appgw-cert"
  }

  gateway_ip_configuration {
    name      = "appgw-gateway-ip-configuration"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip-configuration"
    public_ip_address_id = var.public_ip_address_id
  }

  frontend_port {
    name = "appgw-frontend-port"
    port = 443
  }

  # SSL Certificate Block
  ssl_certificate {
    name                = "appgw-cert"
    key_vault_secret_id = var.certificate_secret_id
  }

  ssl_profile {
    name = "ssl-profile"
    ssl_policy {
      policy_name = "AppGwSslPolicy20220101"
      policy_type = "Predefined"
    }
  }

  ssl_policy {
    policy_name = "AppGwSslPolicy20220101"
    policy_type = "Predefined"
  }

  firewall_policy_id = azurerm_web_application_firewall_policy.policy.id
}
