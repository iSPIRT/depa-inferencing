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
  extra_tags = {
    Owner = "ispirt"
  }

  # List of additional Virtual Network IDs to link the Key Vault private DNS zone to.
  # This allows VMs in other VNets to access the Key Vault via private endpoint.
  # Note: VNets with dedicated private endpoints (like the VM VNet) should NOT be listed here,
  # as the private endpoint creation will handle the DNS zone linking automatically.
  # Example: ["/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/other-vnet"]
  additional_virtual_network_ids = []

  # VM VNet configuration for additional private endpoint
  # This creates a dedicated private endpoint for the externally provisioned VM
  vm_vnet_resource_group_name = "<your_runner_vm_resource_group>"
  vm_vnet_name                = "<your_runner_vm_vnet_name>"
  vm_subnet_name              = "<your_runner_vm_subnet_name>"
}

