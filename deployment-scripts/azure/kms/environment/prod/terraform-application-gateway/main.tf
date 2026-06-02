# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

# Phase 3 (prod): same phased layout as UAT (66adae1+), scoped to ledger runner connectivity
# for this maintenance window. AGW / Let's Encrypt modules match demo when prod catches up.
#
# Prerequisites:
# 1. Phase 1 resources exist in Azure (colleague apply).
# 2. Phase 2 KV private endpoints applied (recommended before this phase).
# 3. Ledger PLS exists; kmspls PE is existing_kms_ledger_private_ip in locals.tf.

locals {
  base_tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Workload    = "depa-inferencing-kms"
  }
}

module "ledger_networking" {
  source = "../../../services/ledger_networking"

  name                           = local.ledger_name
  resource_group_name            = data.azurerm_resource_group.kms.name
  location                       = data.azurerm_resource_group.kms.location
  private_link_service_alias     = local.ledger_private_link_service_alias
  private_endpoint_subnet_id     = data.azurerm_subnet.private_endpoint.id
  virtual_network_id             = data.azurerm_virtual_network.kms.id
  existing_kms_ledger_private_ip = local.existing_kms_ledger_private_ip
  vm_private_endpoint_subnet_id  = data.azurerm_subnet.vm_private_endpoint.id
  vm_virtual_network_id          = data.azurerm_virtual_network.vm.id
  tags                           = merge(local.base_tags, local.extra_tags)
}
