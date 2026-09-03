# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

locals {
  environment  = "uat" # uat or prod
  region_short = "cin"

  resource_group_name      = "depa-inferencing-kms-${local.environment}-${local.region_short}-rg"
  application_gateway_name = "depa-inferencing-kms-${local.environment}-${local.region_short}-agw"
  ledger_name              = "depa-inferencing-kms-${local.environment}-${local.region_short}"

  # Must match the trusted root certificate entry name on the gateway backend
  # HTTP settings (see services/application_gateway).
  trusted_root_certificate_name = "ledger-root-cert"

  # Storage account: globally unique, <=24 lowercase alphanumeric.
  storage_account_name = "depainfkmsrec${local.environment}${local.region_short}"
  function_app_name    = "depa-inferencing-kms-${local.environment}-${local.region_short}-agw-certsync"

  # NCRONTAB: every minute.
  reconcile_schedule = "0 */1 * * * *"

  tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = "ispirt"
    Workload    = "depa-inferencing-kms"
  }
}
