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

  # Public URI allowlist (Lowercase+UrlDecode via WAF rule). Empty waf_allowed_public_uri_regex → regex below.
  # Optional trailing slash + optional query per path. Override for e.g. /.well-known if HTTP+ACME shares this policy.
  # Public KMS paths (sans pubkey): pubkey uses a separate BeginsWith rule — Azure Regex alternation skipped it wrongly.
  default_kms_public_uri_allow_regex = "^(/app/listpubkeys/?(?:\\?[^#]*)?$|/app/key/?(?:\\?[^#]*)?$|/app/unwrapkey/?(?:\\?[^#]*)?)$"
  kms_public_uri_allow_regex         = var.waf_allowed_public_uri_regex != "" ? var.waf_allowed_public_uri_regex : local.default_kms_public_uri_allow_regex
}

resource "azurerm_public_ip" "gateway" {
  count               = var.public_ip_id == "" ? 1 : 0
  name                = "${var.name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

data "azurerm_public_ip" "existing" {
  count               = var.public_ip_id != "" ? 1 : 0
  name                = split("/", var.public_ip_id)[8]
  resource_group_name = split("/", var.public_ip_id)[4]
}

locals {
  public_ip_id      = var.public_ip_id != "" ? var.public_ip_id : azurerm_public_ip.gateway[0].id
  public_ip_address = var.public_ip_id != "" ? data.azurerm_public_ip.existing[0].ip_address : azurerm_public_ip.gateway[0].ip_address
  public_ip_fqdn    = var.public_ip_id != "" ? data.azurerm_public_ip.existing[0].fqdn : azurerm_public_ip.gateway[0].fqdn
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

      # CRS 942340/430/440 false-positive KMS JSON bodies; TF exclusions cannot scope by RequestUri. KMS-only policy — do not reuse blindly.
      dynamic "rule_group_override" {
        for_each = var.waf_sqli_rule_overrides_enabled && var.waf_rule_set_type == "OWASP" ? [1] : []
        content {
          rule_group_name = "REQUEST-942-APPLICATION-ATTACK-SQLI"
          rule {
            id      = "942340"
            enabled = false
          }
          rule {
            id      = "942430"
            enabled = false
          }
          rule {
            id      = "942440"
            enabled = false
          }
        }
      }
    }
  }

  custom_rules {
    name      = "ValidateHostHeader"
    priority  = 1
    rule_type = "MatchRule"
    action    = "Block"

    # Block unless Host equals allowed_hostname exactly.
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

  # Order: pubkey Allow → composite Allow → Block remaining /app/* → block CCF routes (regex must wholly match URIs).
  dynamic "custom_rules" {
    for_each = var.waf_public_allowlist_enabled ? [1] : []
    content {
      name      = "AllowKmsPubkeyPath"
      priority  = 2
      rule_type = "MatchRule"
      action    = "Allow"

      match_conditions {
        match_variables {
          variable_name = "RequestUri"
        }
        operator           = "BeginsWith"
        match_values       = ["/app/pubkey"]
        negation_condition = false
        transforms         = ["Lowercase", "UrlDecode"]
      }
    }
  }

  dynamic "custom_rules" {
    for_each = var.waf_public_allowlist_enabled ? [1] : []
    content {
      name      = "AllowKmsPublicApiPaths"
      priority  = 3
      rule_type = "MatchRule"
      action    = "Allow"

      match_conditions {
        match_variables {
          variable_name = "RequestUri"
        }
        operator           = "Regex"
        match_values       = [local.kms_public_uri_allow_regex]
        negation_condition = false
        transforms         = ["Lowercase", "UrlDecode"]
      }
    }
  }

  dynamic "custom_rules" {
    for_each = var.waf_public_allowlist_enabled ? [1] : []
    content {
      name      = "BlockUnlistedAppPaths"
      priority  = 4
      rule_type = "MatchRule"
      action    = "Block"

      match_conditions {
        match_variables {
          variable_name = "RequestUri"
        }
        operator           = "Regex"
        match_values       = ["^/app/"]
        negation_condition = false
        transforms         = ["Lowercase", "UrlDecode"]
      }
    }
  }

  dynamic "custom_rules" {
    for_each = var.waf_public_allowlist_enabled ? [1] : []
    content {
      name      = "BlockNodeAndGovPrefixes"
      priority  = 5
      rule_type = "MatchRule"
      action    = "Block"

      match_conditions {
        match_variables {
          variable_name = "RequestUri"
        }
        operator           = "Regex"
        match_values       = ["^/(node|gov)(/.*)?$"]
        negation_condition = false
        transforms         = ["Lowercase", "UrlDecode"]
      }
    }
  }

  dynamic "custom_rules" {
    for_each = var.waf_public_allowlist_enabled ? [1] : []
    content {
      name      = "BlockReceiptPrefixes"
      priority  = 6
      rule_type = "MatchRule"
      action    = "Block"

      match_conditions {
        match_variables {
          variable_name = "RequestUri"
        }
        operator           = "BeginsWith"
        match_values       = ["/receipt"]
        negation_condition = false
        transforms         = ["Lowercase", "UrlDecode"]
      }
    }
  }

}

resource "azurerm_application_gateway" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  zones               = var.zones
  tags                = var.tags
  http2_enabled       = var.http2_enabled

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  sku {
    name     = var.sku_name
    tier     = var.sku_tier
    capacity = var.capacity
  }

  firewall_policy_id                = azurerm_web_application_firewall_policy.this.id
  force_firewall_policy_association = true

  gateway_ip_configuration {
    name      = "depa-inferencing-gateway-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "depa-inferencing-https-port"
    port = 443
  }

  frontend_port {
    name = "depa-inferencing-http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = local.public_ip_id
  }

  backend_address_pool {
    name  = "depa-inferencing-backend-pool"
    fqdns = [var.backend_address]
  }

  # Backend pool for ACME HTTP-01 challenges (Let's Encrypt frontend cert renewal).
  # Points at the static website endpoint of a private storage account; reachable
  # from the gateway via privatelink.web.core.windows.net.
  backend_address_pool {
    name  = "letsencrypt-acme-backend"
    fqdns = [var.acme_challenge_backend_fqdn]
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
    cookie_based_affinity               = "Enabled"
    port                                = var.backend_port
    protocol                            = "Https"
    request_timeout                     = 20
    probe_name                          = "depa-inferencing-health-probe"
    trusted_root_certificate_names      = [var.trusted_root_certificate_name]
    pick_host_name_from_backend_address = var.backend_hostname == "" ? true : false
    host_name                           = var.backend_hostname != "" ? var.backend_hostname : null
  }

  # HTTP settings for the ACME challenge backend (Azure Storage static website).
  # Storage's web endpoint is HTTPS-only and requires SNI matching the account FQDN.
  backend_http_settings {
    name                                = "letsencrypt-acme-http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = "letsencrypt-acme-probe"
  }

  http_listener {
    name                           = "depa-inferencing-https-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "depa-inferencing-https-port"
    protocol                       = "Https"
    ssl_certificate_name           = var.ssl_certificate_name
    host_name                      = var.allowed_hostname
  }

  # HTTP listener used only for ACME HTTP-01 challenges and HTTPS redirects.
  http_listener {
    name                           = "depa-inferencing-http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "depa-inferencing-http-port"
    protocol                       = "Http"
    host_name                      = var.allowed_hostname
  }

  # Redirect everything on port 80 to HTTPS, except /.well-known/acme-challenge/*
  # which is path-routed to the storage backend below.
  redirect_configuration {
    name                 = "http-to-https-redirect"
    redirect_type        = "Permanent"
    target_listener_name = "depa-inferencing-https-listener"
    include_path         = true
    include_query_string = true
  }

  url_path_map {
    name                                = "http-path-map"
    default_redirect_configuration_name = "http-to-https-redirect"

    path_rule {
      name                       = "acme-challenge"
      paths                      = ["/.well-known/acme-challenge/*"]
      backend_address_pool_name  = "letsencrypt-acme-backend"
      backend_http_settings_name = "letsencrypt-acme-http-settings"
    }
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

  # Probe for the ACME challenge backend. We accept 4xx because the storage
  # static website returns 404 for "/" (we never publish an index page); the
  # only path we care about is /.well-known/acme-challenge/* which is short-lived.
  probe {
    name                                      = "letsencrypt-acme-probe"
    protocol                                  = "Https"
    path                                      = "/"
    pick_host_name_from_backend_http_settings = true
    interval                                  = 60
    timeout                                   = 30
    unhealthy_threshold                       = 3
    minimum_servers                           = 0

    match {
      status_code = ["200-499"]
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

  request_routing_rule {
    name               = "depa-inferencing-http-rule"
    rule_type          = "PathBasedRouting"
    http_listener_name = "depa-inferencing-http-listener"
    url_path_map_name  = "http-path-map"
    priority           = 90
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

