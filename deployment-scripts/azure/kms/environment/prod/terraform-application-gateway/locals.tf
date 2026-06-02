# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

locals {
  environment  = "prod"
  operator     = "tf"
  region       = "centralindia"
  region_short = "cin"

  subscription_id = "<your_subscription_id>"
  tenant_id       = "<your_tenant_id>"

  resource_group_name  = "depa-inferencing-kms-${local.environment}-${local.region_short}-rg"
  virtual_network_name = "depa-inferencing-kms-${local.environment}-${local.region_short}-vnet"
  ledger_name          = "depa-inferencing-kms-${local.environment}-${local.region_short}"

  # Azure-provisioned KMS ledger PE (eg. depa-inferencing-cin-kmspls-pe) — do not recreate via Terraform.
  existing_kms_ledger_private_ip = ""

  ledger_private_link_service_alias = ""

  vm_vnet_resource_group_name = "<your_runner_vm_resource_group>"
  vm_vnet_name                = "<your_runner_vm_vnet_name>"
  vm_subnet_name              = "<your_runner_vm_subnet_name>"

  extra_tags = {
    Owner = "ispirt"
  }
}
