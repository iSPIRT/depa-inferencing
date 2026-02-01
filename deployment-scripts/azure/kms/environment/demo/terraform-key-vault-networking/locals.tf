# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.

locals {
  environment  = "prod"
  operator     = "tf"
  region       = "centralindia"
  region_short = "cin"

  subscription_id = "2a5f1e30-b076-4cb2-9235-2036241dedf0"
  tenant_id       = "3039a1ed-8db4-4652-a69b-9ff4e265e18d"

  resource_group_name      = "depa-inferencing-kms-${local.environment}-${local.region_short}-rg"
  key_vault_name           = "depa-inferencing-${local.region_short}-kv"
  virtual_network_name     = "depa-inferencing-kms-${local.environment}-${local.region_short}-vnet"
  application_gateway_name = "depa-inferencing-kms-${local.environment}-${local.region_short}-agw"

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
  vm_vnet_resource_group_name = "depa-inferencing-prod"
  vm_vnet_name                = "vnet-depainf-cicd"
  vm_subnet_name              = "snet-depainf-cicd" # Subnet name for private endpoint in VM VNet

  # KMS private link DNS configuration (from Phase 1 KMS deployment)
  kms_private_dns_record_name = "depa-inferencing-kms-${local.environment}-${local.region_short}-pls-api"
}

