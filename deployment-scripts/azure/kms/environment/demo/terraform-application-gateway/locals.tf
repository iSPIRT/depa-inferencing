# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

locals {
  environment  = "prod"
  operator     = "tf"
  region       = "centralindia"
  region_short = "cin"

  subscription_id = "<your_subscription_id>"
  tenant_id       = "<your_tenant_id>"

  resource_group_name      = "depa-inferencing-kms-${local.environment}-${local.region_short}-rg"
  key_vault_name           = "depa-inferencing-${local.region_short}-kv"
  virtual_network_name     = "depa-inferencing-kms-${local.environment}-${local.region_short}-vnet"
  application_gateway_name = "depa-inferencing-kms-${local.environment}-${local.region_short}-agw"
  managed_identity_name    = "depa-inferencing-kms-${local.region_short}-mi"
  ledger_name              = "depa-inferencing-kms-${local.environment}-${local.region_short}"

  # Private Link Service alias for the Confidential Ledger.
  # This must be filled in after the manual step of creating the PLS out-of-band.
  # Example: depa-inferencing-kms-prod-cin-pls.bda3e1dd-05f2-4760-aab6-df4ebb5aaa90.centralindia.azure.privatelinkservice
  ledger_private_link_service_alias = "" # REQUIRED: Fill in after manual PLS creation

  ssl_certificate_name                                    = "depa-inferencing-kms-${local.environment}-${local.region_short}-frontend-cert"
  diagnostics_log_analytics_workspace_name                = "depa-inferencing-sentinel-workspace"
  diagnostics_log_analytics_workspace_resource_group_name = "depa-inferencing-sentinel-rg"
  allowed_hostname                                        = "depa-inferencing-kms-azure.ispirt.in"

  # CI runner VNet (matches Phase 2 vm_* values). Used to create a second
  # private endpoint for the ACME challenge storage account so the renewal
  # workflow can upload challenge tokens from the runner.
  vm_vnet_resource_group_name = "<your_runner_vm_resource_group>"
  vm_vnet_name                = "<your_runner_vm_vnet_name>"
  vm_subnet_name              = "<your_runner_vm_subnet_name>"

  # Object ID of the CI principal (the identity behind AZURE_AKS_CLIENT_ID).
  # Granted Storage Blob Data Contributor on the ACME storage account so the
  # renewal workflow can upload challenge tokens via `az --auth-mode login`.
  ci_principal_id = "<your_ci_principal_object_id>"

  extra_tags = {
    Owner = "ispirt"
  }
}
