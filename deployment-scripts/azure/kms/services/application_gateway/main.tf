# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

resource "null_resource" "convert_cert_to_cer" {
  triggers = {
    cert_pem = var.trusted_root_certificate
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${var.trusted_root_certificate}' | openssl x509 -inform PEM -outform DER | base64 > /tmp/ledger_cert.cer
    EOT
  }
}

data "local_file" "cert_cer" {
  filename   = "/tmp/ledger_cert.cer"
  depends_on = [null_resource.convert_cert_to_cer]
}

locals {
  trusted_root_certificate_cer = trimspace(data.local_file.cert_cer.content)
}

resource "azurerm_public_ip" "gateway" {
  name                = "${var.name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_application_gateway" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  depends_on = [null_resource.convert_cert_to_cer]

  sku {
    name     = var.sku_name
    tier     = var.sku_tier
    capacity = var.capacity
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  backend_address_pool {
    name  = "backend-pool"
    fqdns = [var.backend_address]
  }

  trusted_root_certificate {
    name = var.trusted_root_certificate_name
    data = local.trusted_root_certificate_cer
  }

  backend_http_settings {
    name                  = "backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = var.backend_port
    protocol              = "Https"
    request_timeout       = 20
    probe_name            = "health-probe"
    trusted_root_certificate_names = [var.trusted_root_certificate_name]
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  dynamic "http_listener" {
    for_each = var.ssl_certificate_name != "" ? [1] : []
    content {
      name                           = "https-listener"
      frontend_ip_configuration_name = "frontend-ip"
      frontend_port_name             = "https-port"
      protocol                       = "Https"
      ssl_certificate_name           = var.ssl_certificate_name
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.ssl_certificate_name != "" ? [1] : []
    content {
      name                       = "https-rule"
      rule_type                  = "Basic"
      http_listener_name         = "https-listener"
      backend_address_pool_name   = "backend-pool"
      backend_http_settings_name = "backend-http-settings"
      priority                   = 100
    }
  }

  probe {
    name                = "health-probe"
    protocol            = "Https"
    path                = var.health_probe_path
    host                = var.backend_address
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    minimum_servers     = 0
  }

  request_routing_rule {
    name                       = "http-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name   = "backend-pool"
    backend_http_settings_name = "backend-http-settings"
    priority                   = 10
  }

}

