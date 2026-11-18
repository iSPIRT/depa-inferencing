# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# Azure resources used by the system tests in iSPIRT/azure-depa-inferencing-kms
# (.github/workflows/system-test.yml). The tests create and delete short-lived
# Confidential Ledgers in this resource group, so the identity only needs
# Contributor here and has no access to the UAT or Production KMS.

locals {
  region = "centralindia"

  subscription_id = "<your_subscription_id>"
  tenant_id       = "<your_tenant_id>"

  resource_group_name   = "depa-inferencing-kms-test"
  managed_identity_name = "depa-inferencing-kms-test-mi"

  github_repository = "iSPIRT/azure-depa-inferencing-kms"
  # Must match the `environment:` of the system test job.
  github_environment = "CI"

  tags = {
    Environment = "test"
    ManagedBy   = "Terraform"
    Workload    = "depa-inferencing-kms"
    Owner       = "ispirt"
  }
}

module "resource_group" {
  source   = "../../../services/resource_group"
  name     = local.resource_group_name
  location = local.region
  tags     = local.tags
}

module "managed_identity" {
  source              = "../../../services/managed_identity"
  name                = local.managed_identity_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = local.tags
  github_repository   = local.github_repository
  github_environments = [local.github_environment]
}

resource "azurerm_role_assignment" "managed_identity_rg_contributor" {
  principal_id         = module.managed_identity.principal_id
  role_definition_name = "Contributor"
  scope                = module.resource_group.id
}
