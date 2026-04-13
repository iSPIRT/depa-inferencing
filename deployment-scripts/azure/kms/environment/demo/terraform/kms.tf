# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

locals {
  environment  = "prod"
  operator     = "tf"
  region       = "centralindia"
  region_short = "cin"

  subscription_id = "<your_subscription_id>"
  tenant_id       = "<your_tenant_id>"

  resource_group_name = "depa-inferencing-kms-${local.environment}-${local.region_short}-rg"

  enable_ddos_protection = false

  extra_tags = {
    Owner = "ispirt"
  }
}

module "kms" {
  source = "../../../modules/kms"

  operator                                                = local.operator
  environment                                             = local.environment
  tenant_id                                               = local.tenant_id
  region                                                  = local.region
  region_short                                            = local.region_short
  resource_group_name                                     = local.resource_group_name
  enable_ddos_protection                                  = local.enable_ddos_protection
  extra_tags                                              = local.extra_tags
  github_repository                                       = "iSPIRT/azure-depa-inferencing-kms"
  github_branch                                           = "main"
  # Note: Application Gateway is deployed separately via terraform-application-gateway/
}

