# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

locals {
  environment  = "prod"
  operator     = "tf"
  region       = "centralindia"
  region_short = "cin"

  subscription_id = "2a5f1e30-b076-4cb2-9235-2036241dedf0"
  tenant_id       = "3039a1ed-8db4-4652-a69b-9ff4e265e18d"

  resource_group_name = "depa-inferencing-kms-${local.environment}-${local.region_short}-rg"

  extra_tags = {
    Owner = "ispirt"
  }

  ssl_certificate_name                                    = "depa-inferencing-kms-prod-cin-frontend-cert" # Name of the SSL certificate in Key Vault for Application Gateway.
  diagnostics_log_analytics_workspace_name                = "depa-inferencing-sentinel-workspace"         # Optional: Log Analytics workspace name for Application Gateway diagnostics.
  diagnostics_log_analytics_workspace_resource_group_name = "depa-inferencing-sentinel-rg"                # Optional: Resource group that hosts the Log Analytics workspace.

  allowed_hostname = "depa-inferencing-kms-azure.ispirt.in" # Allowed hostname for Application Gateway Host header validation.

  # KMS private link configuration (resource ID or alias as provided)
  kms_private_link_resource_id_or_alias = ""

}

module "kms" {
  source = "../../../modules/kms"

  operator                                                = local.operator
  environment                                             = local.environment
  tenant_id                                               = local.tenant_id
  region                                                  = local.region
  region_short                                            = local.region_short
  resource_group_name                                     = local.resource_group_name
  extra_tags                                              = local.extra_tags
  github_repository                                       = "iSPIRT/azure-depa-inferencing-kms"
  github_branch                                           = "main"
  ssl_certificate_name                                    = local.ssl_certificate_name
  diagnostics_log_analytics_workspace_name                = local.diagnostics_log_analytics_workspace_name
  diagnostics_log_analytics_workspace_resource_group_name = local.diagnostics_log_analytics_workspace_resource_group_name
  allowed_hostname                                         = local.allowed_hostname
  kms_private_link_resource_id_or_alias                     = local.kms_private_link_resource_id_or_alias
  # Note: additional_virtual_network_ids is only used in the key-vault-networking deployment, not here
}

