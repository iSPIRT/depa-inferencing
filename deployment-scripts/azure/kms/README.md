# Key Management Service (KMS) Terraform Deployment

This directory contains Terraform configurations for deploying the Key Management Service (KMS) infrastructure on Azure. The KMS provides secure key management using Azure Key Vault, Confidential Ledger, and Application Gateway.

## Overview

The KMS deployment consists of two phases:

1. **Main KMS Deployment** - Creates core infrastructure resources
2. **Key Vault Networking Deployment** - Configures private endpoints and network security

## Directory Structure

```
kms/
├── environment/
│   └── demo/
│       ├── terraform/                    # Main KMS deployment
│       │   ├── kms.tf                    # Main configuration
│       │   ├── outputs.tf                # Output values
│       │   └── terraform.tf              # Terraform backend configuration
│       └── terraform-key-vault-networking/  # Networking deployment
│           ├── main.tf                   # Networking configuration
│           ├── data.tf                   # Data sources for existing resources
│           ├── locals.tf                 # Local variables and VM configuration
│           ├── outputs.tf                # Output values
│           ├── terraform.tf              # Terraform backend configuration
│           └── README.md                 # Detailed networking deployment guide
├── modules/
│   └── kms/                              # Main KMS module
│       ├── main.tf                       # Module implementation
│       ├── variables.tf                  # Module input variables
│       └── outputs.tf                    # Module outputs
└── services/                             # Reusable service modules
    ├── application_gateway/              # Application Gateway service
    ├── confidential_ledger/              # Confidential Ledger service
    ├── key_vault/                        # Key Vault service
    ├── key_vault_networking/             # Key Vault networking (private endpoints)
    ├── managed_identity/                 # Managed Identity service
    ├── resource_group/                   # Resource Group service
    ├── storage_account/                  # Storage Account service
    └── virtual_network/                  # Virtual Network service
```

## Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.0
- Azure CLI configured with appropriate credentials
- Access to the target Azure subscription and resource groups

## Deployment Process

### Phase 1: Main KMS Deployment

Deploy the core KMS infrastructure resources:

```bash
cd environment/demo/terraform
terraform init
terraform plan
terraform apply
```

**What gets created:**
- Resource Group
- Managed Identity (with GitHub federated credentials)
- Virtual Network with subnets
- Key Vault (with public access enabled initially)
- Confidential Ledger
- Application Gateway

### Phase 2: Key Vault Networking Deployment

Configure private endpoints and disable public access:

```bash
cd ../terraform-key-vault-networking
terraform init
terraform plan

# Import the existing Key Vault to manage public_network_access_enabled
terraform import azurerm_key_vault.disable_public_access \
  /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{vault-name}

terraform plan  # Verify the import
terraform apply
```

**What gets created:**
- Private endpoint for Key Vault (in KMS VNet)
- Private endpoint for externally provisioned VM (if configured)
- Private DNS zone for Key Vault
- DNS A records with IP addresses from all private endpoints
- VNet links for DNS zone resolution
- **Disables public network access** on Key Vault

## Configuration

### Main KMS Configuration

Edit `environment/demo/terraform/kms.tf` to configure:
- Environment, region, and subscription details
- SSL certificate name for Application Gateway
- Log Analytics workspace for diagnostics
- GitHub repository for managed identity federated credentials

### Key Vault Networking Configuration

Edit `environment/demo/terraform-key-vault-networking/locals.tf` to configure:

#### VM Private Endpoint (Optional)

If you have an externally provisioned VM that needs to access the Key Vault:

```hcl
# VM VNet configuration for additional private endpoint
vm_vnet_resource_group_name = "your-vm-resource-group"
vm_vnet_name                = "your-vm-vnet-name"
vm_subnet_name              = "your-subnet-name"  # Subnet for private endpoint
```

**Important Notes:**
- The VM VNet should **NOT** be listed in `additional_virtual_network_ids` if you're creating a private endpoint for it
- The subnet must exist in the VM's VNet and be delegated for private endpoints
- The private endpoint will be created in the specified subnet

#### Additional VNet Links (Optional)

To link the private DNS zone to other VNets (without creating private endpoints):

```hcl
additional_virtual_network_ids = [
  "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/other-vnet"
]
```

## Key Components

### Key Vault
- Stores SSL certificates and secrets
- Initially created with public access enabled
- Public access is disabled in Phase 2 after private endpoints are configured
- Uses RBAC for authorization

### Confidential Ledger
- Provides tamper-proof audit logging
- Backed by Azure Key Vault for certificate management
- Accessible via Application Gateway

### Application Gateway
- Provides public-facing HTTPS endpoint
- Terminates SSL using certificates from Key Vault
- Routes traffic to Confidential Ledger backend
- Uses private endpoint to access Key Vault for certificate retrieval

### Private Endpoints
- **Main Private Endpoint**: Created in the KMS VNet for Application Gateway access
- **VM Private Endpoint**: Optional separate endpoint for externally provisioned VMs
- Both endpoints are registered in the same private DNS zone
- DNS A record contains IP addresses from all endpoints for load balancing

### Private DNS Zone
- Zone: `privatelink.vaultcore.azure.net`
- Linked to KMS VNet and VM VNet (if configured)
- Provides DNS resolution for Key Vault private endpoints

## Network Architecture

```
Internet
   │
   ▼
Application Gateway (Public IP)
   │
   ▼
Confidential Ledger (Private)
   │
   │
   ├─► Key Vault (via Private Endpoint in KMS VNet)
   │
   └─► Key Vault (via Private Endpoint in VM VNet) ──► Externally Provisioned VM
```

## Troubleshooting

### Duplicate DNS Zone Link Error

If you encounter an error about a private DNS zone already being linked to a VNet:

1. Check if the VNet is listed in both `additional_virtual_network_ids` and has a private endpoint configured
2. Remove the VNet from `additional_virtual_network_ids` if a private endpoint is being created
3. If a link already exists, you may need to import it or remove it manually:

```bash
# List existing DNS zone links
az network private-dns link vnet list \
  --resource-group {rg-name} \
  --zone-name privatelink.vaultcore.azure.net

# Remove duplicate link if needed
az network private-dns link vnet delete \
  --resource-group {rg-name} \
  --zone-name privatelink.vaultcore.azure.net \
  --name {link-name}
```

### Key Vault Import Issues

If the Key Vault import fails, ensure:
- The Key Vault resource ID is correct
- You have appropriate permissions
- The Key Vault exists from Phase 1 deployment

### VM Cannot Access Key Vault

If the externally provisioned VM cannot access Key Vault:
1. Verify the private endpoint is created in the correct subnet
2. Check that the DNS zone is linked to the VM's VNet
3. Ensure the VM's subnet allows outbound traffic to the private endpoint
4. Verify DNS resolution from the VM: `nslookup {key-vault-name}.vault.azure.net`

## Outputs

### Main KMS Deployment
- Resource group name and ID
- Key Vault URI and ID
- Confidential Ledger endpoint
- Application Gateway public IP
- Managed Identity principal ID

### Key Vault Networking Deployment
- Private DNS zone ID and name
- Main private endpoint ID
- VM private endpoint ID (if configured)

## Security Considerations

- Key Vault public access is disabled after private endpoints are configured
- All Key Vault access goes through private endpoints
- Network ACLs are set to deny by default (Azure Services bypass enabled)
- Application Gateway uses managed identity to access Key Vault
- Confidential Ledger uses managed identity for authentication

## Additional Resources

- [Key Vault Networking README](environment/demo/terraform-key-vault-networking/README.md) - Detailed guide for networking deployment
- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Azure Private Endpoints](https://docs.microsoft.com/azure/private-link/private-endpoint-overview)
- [Confidential Ledger Documentation](https://docs.microsoft.com/azure/confidential-ledger/)
