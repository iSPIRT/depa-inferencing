# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

locals {
  environment = "prod"
  operator    = "tf"
  region      = "centralindia"
  region_short = "cin"

  subscription_id = "2a5f1e30-b076-4cb2-9235-2036241dedf0"
  tenant_id       = "3039a1ed-8db4-4652-a69b-9ff4e265e18d"

  resource_group_name = "depa-inferencing-kms-${local.environment}-${local.region_short}-rg"

  extra_tags = {
    Owner = "ispirt"
  }
}

module "kms" {
  source = "../../../modules/kms"

  operator             = local.operator
  environment          = local.environment
  tenant_id            = local.tenant_id
  region               = local.region
  region_short         = local.region_short
  resource_group_name  = local.resource_group_name
  extra_tags           = local.extra_tags
}

