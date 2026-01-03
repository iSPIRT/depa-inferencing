# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

locals {
  default_resource_group_name  = "depa-inferencing-kms-${var.environment}-${var.region_short}-rg"
  default_identity_name        = "depa-inferencing-kms-${var.region_short}-mi"
  default_key_vault_name       = "depa-inferencing-${var.region_short}-kv"
  default_certificate_name     = "depa-inferencing-kms-${var.environment}-${var.region_short}-member-cert"
  default_ledger_name          = "depa-inferencing-kms-${var.environment}-${var.region_short}"
  default_vnet_name            = "depa-inferencing-kms-${var.environment}-${var.region_short}-vnet"
  default_app_gateway_name     = "depa-inferencing-kms-${var.environment}-${var.region_short}-agw"
  default_storage_account_name = lower(substr(replace(replace("depainfkms${var.environment}${var.region_short}ldgbk", "-", ""), "_", ""), 0, 24))

  resource_group_name = (
    var.resource_group_name != "" ?
    var.resource_group_name :
    local.default_resource_group_name
  )

  managed_identity_name = (
    var.managed_identity_name != "" ?
    var.managed_identity_name :
    local.default_identity_name
  )

  key_vault_name = (
    var.key_vault_name != "" ?
    var.key_vault_name :
    local.default_key_vault_name
  )

  certificate_name = (
    var.certificate_name != "" ?
    var.certificate_name :
    local.default_certificate_name
  )

  ledger_name = (
    var.ledger_name != "" ?
    var.ledger_name :
    local.default_ledger_name
  )

  virtual_network_name = (
    var.virtual_network_name != "" ?
    var.virtual_network_name :
    local.default_vnet_name
  )

  application_gateway_name = (
    var.application_gateway_name != "" ?
    var.application_gateway_name :
    local.default_app_gateway_name
  )

  storage_account_name = (
    var.storage_account_name != "" ?
    var.storage_account_name :
    local.default_storage_account_name
  )

  base_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Workload    = "depa-inferencing-kms"
  }
}

module "resource_group" {
  source   = "../../services/resource_group"
  name     = local.resource_group_name
  location = var.region
  tags     = merge(local.base_tags, var.extra_tags)
}

module "managed_identity" {
  source              = "../../services/managed_identity"
  name                = local.managed_identity_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = merge(local.base_tags, var.extra_tags)
  github_repository   = var.github_repository
  github_branch       = var.github_branch
}

resource "azurerm_role_assignment" "managed_identity_rg_contributor" {
  principal_id                     = module.managed_identity.principal_id
  role_definition_name             = "Contributor"
  scope                            = module.resource_group.id
  skip_service_principal_aad_check = true

  depends_on = [
    module.managed_identity,
    module.resource_group,
  ]
}

module "virtual_network" {
  source              = "../../services/virtual_network"
  name                = local.virtual_network_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = merge(local.base_tags, var.extra_tags)
}

# Key Vault: Creates Key Vault with network ACLs and certificate
# This must be deployed first so that certificates are accessible to Azure services
# Note: Private endpoints are deployed separately via the key-vault-networking deployment
module "key_vault" {
  source                     = "../../services/key_vault"
  name                       = local.key_vault_name
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  tenant_id                  = var.tenant_id
  tags                       = merge(local.base_tags, var.extra_tags)
  crypto_principal_ids       = [module.managed_identity.principal_id]
  secrets_user_principal_ids = [module.managed_identity.principal_id]
  certificate_name           = local.certificate_name

  depends_on = [
    module.managed_identity,
  ]
}

module "confidential_ledger" {
  source                                       = "../../services/confidential_ledger"
  name                                         = local.ledger_name
  resource_group_name                          = module.resource_group.name
  location                                     = module.resource_group.location
  tags                                         = merge(local.base_tags, var.extra_tags)
  azuread_based_service_principal_tenant_id    = var.tenant_id
  azuread_based_service_principal_principal_id = module.managed_identity.principal_id
  key_vault_id                                 = module.key_vault.id
  certificate_name                             = local.certificate_name

  depends_on = [
    module.key_vault,
    module.managed_identity,
  ]
}

module "application_gateway" {
  source                                                  = "../../services/application_gateway"
  name                                                    = local.application_gateway_name
  resource_group_name                                     = module.resource_group.name
  location                                                = module.resource_group.location
  subnet_id                                               = module.virtual_network.gateway_subnet_id
  backend_address                                         = replace(module.confidential_ledger.ledger_endpoint, "https://", "")
  backend_hostname                                        = module.confidential_ledger.name
  backend_port                                            = 443
  trusted_root_certificate                                = module.confidential_ledger.ledger_tls_certificate
  ssl_certificate_name                                    = var.ssl_certificate_name
  key_vault_uri                                           = module.key_vault.uri
  managed_identity_id                                     = module.managed_identity.id
  diagnostics_log_analytics_workspace_name                = var.diagnostics_log_analytics_workspace_name
  diagnostics_log_analytics_workspace_resource_group_name = var.diagnostics_log_analytics_workspace_resource_group_name
  tags                                                    = merge(local.base_tags, var.extra_tags)
  health_probe_path                                       = "/node/metrics"
  allowed_hostname                                        = var.allowed_hostname
  depends_on = [
    module.virtual_network,
    module.confidential_ledger,
  ]
}

module "storage_account" {
  source                        = "../../services/storage_account"
  name                          = local.storage_account_name
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  account_tier                  = var.storage_account_tier
  account_replication_type      = var.storage_account_replication_type
  file_share_name               = var.storage_file_share_name
  file_share_quota_gb           = var.storage_file_share_quota_gb
  managed_identity_principal_id = module.managed_identity.principal_id
  tags                          = merge(local.base_tags, var.extra_tags)

  depends_on = [
    module.resource_group,
    module.managed_identity,
  ]
}

