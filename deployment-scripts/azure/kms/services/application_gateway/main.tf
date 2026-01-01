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
  
  # Map rate limit duration minutes to Azure WAF format
  rate_limit_duration_map = {
    1 = "OneMin"
    5 = "FiveMins"
  }
  rate_limit_duration = lookup(local.rate_limit_duration_map, var.rate_limit_duration_minutes, "OneMin")
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

  custom_rules {
    name      = "ValidateHostHeader"
    priority  = 1
    rule_type = "MatchRule"
    action    = "Block"

    # Block requests where Host header does not match the allowed hostname
    # Uses "Equal" operator with negation: block if Host does NOT equal the allowed hostname
    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "Host"
      }
      operator           = "Equal"
      match_values       = [var.allowed_hostname]
      negation_condition = true
    }
  }

  custom_rules {
    name      = "RateLimitByClientIP"
    priority  = 2
    rule_type = "RateLimitRule"
    action    = "Block"
    rate_limit_duration  = local.rate_limit_duration
    rate_limit_threshold = var.rate_limit_threshold

    # Rate limit by client IP address
    # Blocks requests from a client IP if it exceeds the threshold within the duration window
    # Match all requests - rate limiting is automatically grouped by client IP when using RemoteAddr
    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }
      operator           = "IPMatch"
      match_values       = ["0.0.0.0/0"]
      negation_condition = false
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
    host_name                      = var.allowed_hostname
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

  rewrite_rule_set {
    name = "depa-inferencing-rewrite-rule-set"

    rewrite_rule {
      name          = "add-security-headers"
      rule_sequence = 100

      response_header_configuration {
        header_name  = "X-Content-Type-Options"
        header_value = "nosniff"
      }

      response_header_configuration {
        header_name  = "Strict-Transport-Security"
        header_value = "max-age=31536000; includeSubDomains"
      }

      response_header_configuration {
        header_name  = "Cache-Control"
        header_value = "no-cache, no-store, must-revalidate"
      }

      response_header_configuration {
        header_name  = "Pragma"
        header_value = "no-cache"
      }
    }
  }

  request_routing_rule {
    name                       = "depa-inferencing-https-rule"
    rule_type                  = "Basic"
    http_listener_name         = "depa-inferencing-https-listener"
    backend_address_pool_name  = "depa-inferencing-backend-pool"
    backend_http_settings_name = "depa-inferencing-backend-http-settings"
    rewrite_rule_set_name      = "depa-inferencing-rewrite-rule-set"
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

