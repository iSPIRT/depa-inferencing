# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# This deployment creates the Ledger private endpoint networking and Application Gateway.
# It discovers existing resources created by the Phase 1 (terraform/) deployment.
#
# Prerequisites:
# 1. Phase 1 (terraform/) must be deployed first.
# 2. A Private Link Service for the Confidential Ledger must be created out-of-band.
# 3. The PLS alias must be set in locals.tf as ledger_private_link_service_alias.

locals {
  ledger_identity_json   = jsondecode(data.http.ledger_identity.response_body)
  ledger_tls_certificate = local.ledger_identity_json.ledgerTlsCertificate

  base_tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Workload    = "depa-inferencing-kms"
  }
}

# Create private endpoint and DNS for the Confidential Ledger via its Private Link Service.
# This overrides public DNS so the ledger's FQDN resolves to the private endpoint IP within the VNet.
module "ledger_networking" {
  source = "../../../services/ledger_networking"

  name                          = local.ledger_name
  resource_group_name           = data.azurerm_resource_group.kms.name
  location                      = data.azurerm_resource_group.kms.location
  private_link_service_alias    = local.ledger_private_link_service_alias
  private_endpoint_subnet_id    = data.azurerm_subnet.private_endpoint.id
  virtual_network_id            = data.azurerm_virtual_network.kms.id
  vm_private_endpoint_subnet_id = data.azurerm_subnet.vm_private_endpoint.id
  vm_virtual_network_id         = data.azurerm_virtual_network.vm.id
  tags                          = merge(local.base_tags, local.extra_tags)
}

# Private storage account that holds Let's Encrypt HTTP-01 challenge tokens
# served back to the ACME server through the Application Gateway's HTTP listener.
module "letsencrypt_storage" {
  source = "../../../services/letsencrypt_storage"

  # Globally unique, all-lowercase, <=24 chars. Derived from environment+region
  # so each env's account is named deterministically without a separate local.
  name                          = "depainfkmsacme${local.environment}${local.region_short}"
  resource_group_name           = data.azurerm_resource_group.kms.name
  location                      = data.azurerm_resource_group.kms.location
  private_endpoint_subnet_id    = data.azurerm_subnet.private_endpoint.id
  virtual_network_id            = data.azurerm_virtual_network.kms.id
  vm_private_endpoint_subnet_id = data.azurerm_subnet.vm_private_endpoint.id
  vm_virtual_network_id         = data.azurerm_virtual_network.vm.id
  ci_principal_id               = local.ci_principal_id
  tags                          = merge(local.base_tags, local.extra_tags)
}

# Grant the CI principal data-plane access to import new certificate versions
# into Key Vault. Phase 1's `crypto_principal_ids` controls Phase-1-managed
# role grants; this assignment is co-located with the renewal workflow's other
# infra so the cert-refresh setup is self-contained in Phase 3.
resource "azurerm_role_assignment" "ci_kv_certificates_officer" {
  scope                = data.azurerm_key_vault.kms.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = local.ci_principal_id
}

# Application Gateway with the Ledger private endpoint FQDN as backend.
# The backend address is the same FQDN as the public ledger endpoint, but within the VNet
# it resolves to the private endpoint IP via the private DNS zone created above.
module "application_gateway" {
  source = "../../../services/application_gateway"

  name                                                    = local.application_gateway_name
  resource_group_name                                     = data.azurerm_resource_group.kms.name
  location                                                = data.azurerm_resource_group.kms.location
  subnet_id                                               = data.azurerm_subnet.gateway.id
  backend_address                                         = module.ledger_networking.ledger_private_fqdn
  backend_hostname                                        = local.ledger_name
  backend_port                                            = 443
  trusted_root_certificate                                = local.ledger_tls_certificate
  ssl_certificate_name                                    = local.ssl_certificate_name
  key_vault_uri                                           = data.azurerm_key_vault.kms.vault_uri
  managed_identity_id                                     = data.azurerm_user_assigned_identity.kms.id
  diagnostics_log_analytics_workspace_name                = local.diagnostics_log_analytics_workspace_name
  diagnostics_log_analytics_workspace_resource_group_name = local.diagnostics_log_analytics_workspace_resource_group_name
  tags                                                    = merge(local.base_tags, local.extra_tags)
  health_probe_path                                       = "/node/metrics"
  allowed_hostname                                        = local.allowed_hostname
  acme_challenge_backend_fqdn                             = module.letsencrypt_storage.web_endpoint_host
  capacity                                                = local.application_gateway_capacity
  public_ip_id                                            = local.application_gateway_public_ip_id

  gateway_monitor_unhealthy_alert_enabled     = local.gateway_monitor_unhealthy_alert_enabled
  gateway_monitor_alert_email_addresses       = local.gateway_monitor_alert_email_addresses
  gateway_monitor_action_group_name           = local.gateway_monitor_action_group_name
  gateway_monitor_metric_alert_name           = local.gateway_monitor_metric_alert_name
  gateway_monitor_action_group_short_name     = local.gateway_monitor_action_group_short_name
  gateway_monitor_unhealthy_alert_description = local.gateway_monitor_unhealthy_alert_description
  gateway_monitor_additional_action_group_ids = local.gateway_monitor_additional_action_group_ids
  gateway_ledger_backend_http_settings_name   = local.gateway_ledger_backend_http_settings_name
  gateway_monitor_unhealthy_alert_severity    = local.gateway_monitor_unhealthy_alert_severity
  gateway_monitor_alert_frequency             = local.gateway_monitor_alert_frequency
  gateway_monitor_alert_window_size           = local.gateway_monitor_alert_window_size

  depends_on = [
    module.ledger_networking,
    module.letsencrypt_storage,
  ]
}
