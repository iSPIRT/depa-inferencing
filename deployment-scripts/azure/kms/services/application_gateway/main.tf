# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

data "external" "cert_cer" {
  program = ["bash", "-c", <<-EOT
    echo '${var.trusted_root_certificate}' | openssl x509 -inform PEM -outform DER | base64 -w 0 | jq -Rs '{cer: .}'
  EOT
  ]
}

locals {
  trusted_root_certificate_cer = trimspace(data.external.cert_cer.result.cer)
  # Key Vault URI format: https://{vault-name}.vault.azure.net
  # Secret ID format: https://{vault-name}.vault.azure.net/secrets/{secret-name}
  # Trim any trailing slash from URI to avoid double slashes
  key_vault_uri_trimmed               = trimsuffix(var.key_vault_uri, "/")
  ssl_certificate_key_vault_secret_id = "${local.key_vault_uri_trimmed}/secrets/${var.ssl_certificate_name}"
}

resource "azurerm_public_ip" "gateway" {
  name                = "${var.name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_web_application_firewall_policy" "this" {
  name                = "${var.name}-waf-policy"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = var.waf_firewall_mode
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = var.waf_rule_set_type
      version = var.waf_rule_set_version
    }
  }
}

resource "azurerm_application_gateway" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  zones               = var.zones
  tags                = var.tags
  enable_http2        = true

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  sku {
    name     = var.sku_name
    tier     = var.sku_tier
    capacity = var.capacity
  }

  firewall_policy_id = azurerm_web_application_firewall_policy.this.id

  gateway_ip_configuration {
    name      = "depa-inferencing-gateway-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "depa-inferencing-https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  backend_address_pool {
    name  = "depa-inferencing-backend-pool"
    fqdns = [var.backend_address]
  }

  trusted_root_certificate {
    name = var.trusted_root_certificate_name
    data = local.trusted_root_certificate_cer
  }

  ssl_certificate {
    name                = var.ssl_certificate_name
    key_vault_secret_id = local.ssl_certificate_key_vault_secret_id
  }

  backend_http_settings {
    name                                = "depa-inferencing-backend-http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = var.backend_port
    protocol                            = "Https"
    request_timeout                     = 20
    probe_name                          = "depa-inferencing-health-probe"
    trusted_root_certificate_names      = [var.trusted_root_certificate_name]
    pick_host_name_from_backend_address = var.backend_hostname == "" ? true : false
    host_name                           = var.backend_hostname != "" ? var.backend_hostname : null
  }

  http_listener {
    name                           = "depa-inferencing-https-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "depa-inferencing-https-port"
    protocol                       = "Https"
    ssl_certificate_name           = var.ssl_certificate_name
  }

  probe {
    name                = "depa-inferencing-health-probe"
    protocol            = "Https"
    path                = var.health_probe_path
    host                = var.backend_address
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    minimum_servers     = 0

    match {
      status_code = ["200-399"]
    }
  }

  request_routing_rule {
    name                       = "depa-inferencing-https-rule"
    rule_type                  = "Basic"
    http_listener_name         = "depa-inferencing-https-listener"
    backend_address_pool_name  = "depa-inferencing-backend-pool"
    backend_http_settings_name = "depa-inferencing-backend-http-settings"
    priority                   = 100
  }

}

data "azurerm_log_analytics_workspace" "this" {
  count = var.diagnostics_log_analytics_workspace_name != "" ? 1 : 0

  name                = var.diagnostics_log_analytics_workspace_name
  resource_group_name = var.diagnostics_log_analytics_workspace_resource_group_name != "" ? var.diagnostics_log_analytics_workspace_resource_group_name : var.resource_group_name
}

resource "azurerm_monitor_diagnostic_setting" "application_gateway" {
  count = var.diagnostics_log_analytics_workspace_name != "" ? 1 : 0

  name                       = "${var.name}-diagnostics"
  target_resource_id         = azurerm_application_gateway.this.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this[0].id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }
}

