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
  default_logs_storage_account_name = lower(substr(replace(replace("depainfkms${var.environment}${var.region_short}logs", "-", ""), "_", ""), 0, 24))

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

  logs_storage_account_name = (
    var.logs_storage_account_name != "" ?
    var.logs_storage_account_name :
    local.default_logs_storage_account_name
  )

  kms_private_dns_zone_name = data.terraform_remote_state.key_vault_networking.outputs.key_vault_private_dns_zone_name
  kms_private_dns_record_name = "depa-inferencing-kms-${var.environment}-${var.region_short}-pls-api"
  kms_private_dns_record_fqdn = (
    local.kms_private_dns_zone_name != "" ?
    "${local.kms_private_dns_record_name}.${local.kms_private_dns_zone_name}" :
    ""
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

data "terraform_remote_state" "key_vault_networking" {
  backend = "azurerm"

  config = {
    resource_group_name  = local.resource_group_name
    storage_account_name = "${lower(var.environment)}terraformstate${lower(var.region_short)}"
    container_name       = "terraform-key-vault-networking-state"
    key                  = "terraform.tfstate"
  }
}

resource "azurerm_private_endpoint" "kms_private_link" {
  count               = var.kms_private_link_resource_id_or_alias != "" ? 1 : 0
  name                = "${module.resource_group.name}-kmspls-pe"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  subnet_id           = module.virtual_network.kms_private_link_subnet_id

  private_service_connection {
    name                           = "${module.resource_group.name}-kmspls-psc"
    private_connection_resource_id = startswith(var.kms_private_link_resource_id_or_alias, "/subscriptions/") ? var.kms_private_link_resource_id_or_alias : null
    private_connection_resource_alias = startswith(var.kms_private_link_resource_id_or_alias, "/subscriptions/") ? null : var.kms_private_link_resource_id_or_alias
    is_manual_connection           = false
    request_message                = "KMS private link connection"
  }

  depends_on = [
    module.virtual_network,
  ]
}

resource "null_resource" "kms_private_link_approval_check" {
  count = startswith(var.kms_private_link_resource_id_or_alias, "/subscriptions/") ? 1 : 0

  depends_on = [
    azurerm_private_endpoint.kms_private_link,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Checking private endpoint connection approval status..."
      RESOURCE_ID="${var.kms_private_link_resource_id_or_alias}"
      PRIVATE_ENDPOINT_ID="${azurerm_private_endpoint.kms_private_link[0].id}"

      STATUS=$(az network private-endpoint-connection list --id "$RESOURCE_ID" \
        --query "[?privateEndpoint.id=='$PRIVATE_ENDPOINT_ID'].privateLinkServiceConnectionState.status" -o tsv)

      REQUEST_STATUS=$(az network private-endpoint-connection list --id "$RESOURCE_ID" \
        --query "[?privateEndpoint.id=='$PRIVATE_ENDPOINT_ID'].privateLinkServiceConnectionState.description" -o tsv)

      echo "Connection Status: $STATUS"
      echo "Request/Response Status: $REQUEST_STATUS"

      if [ "$STATUS" != "Approved" ]; then
        echo "❌ Private endpoint connection is not approved."
        exit 1
      fi

      echo "✅ Private endpoint connection approved."
    EOT
  }

  triggers = {
    private_endpoint_id = azurerm_private_endpoint.kms_private_link[0].id
  }
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

# Storage Account for KMS logs (created before Confidential Ledger for diagnostics)
resource "azurerm_storage_account" "logs" {
  name                            = local.logs_storage_account_name
  resource_group_name             = module.resource_group.name
  location                        = module.resource_group.location
  account_tier                    = var.logs_storage_account_tier
  account_replication_type        = var.logs_storage_account_replication_type
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = merge(local.base_tags, var.extra_tags, {
    Purpose = "KMS-Logs"
  })
}

# Grant the managed identity Storage Blob Data Contributor role for logs
resource "azurerm_role_assignment" "logs_storage_blob_data_contributor" {
  scope                            = azurerm_storage_account.logs.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = module.managed_identity.principal_id
  skip_service_principal_aad_check = true

  depends_on = [
    azurerm_storage_account.logs,
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
  logs_storage_account_id                      = azurerm_storage_account.logs.id

  depends_on = [
    module.key_vault,
    module.managed_identity,
    azurerm_storage_account.logs,
  ]
}

module "application_gateway" {
  source                                                  = "../../services/application_gateway"
  name                                                    = local.application_gateway_name
  resource_group_name                                     = module.resource_group.name
  location                                                = module.resource_group.location
  subnet_id                                               = module.virtual_network.gateway_subnet_id
  backend_address                                         = local.kms_private_dns_record_fqdn != "" ? local.kms_private_dns_record_fqdn : replace(module.confidential_ledger.ledger_endpoint, "https://", "")
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

