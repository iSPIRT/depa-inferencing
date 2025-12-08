# Key Vault Networking Deployment

This is a separate Terraform deployment that sets up private endpoints and DNS configuration for the Key Vault.

## Prerequisites

The main KMS deployment must be completed first. This deployment discovers existing resources using data sources.

## Deployment Order

1. **First**: Deploy the main KMS resources
   ```bash
   cd ../terraform
   terraform init
   terraform plan
   terraform apply
   ```

2. **Second**: Deploy Key Vault networking (this deployment)
   ```bash
   cd terraform-key-vault-networking
   terraform init
   terraform plan
   
   # Import the existing Key Vault into this state to manage public_network_access_enabled
   # Replace {subscription-id}, {rg-name}, and {vault-name} with actual values from locals.tf
   terraform import azurerm_key_vault.disable_public_access /subscriptions/2a5f1e30-b076-4cb2-9235-2036241dedf0/resourceGroups/depa-inferencing-kms-prod-cin-rg/providers/Microsoft.KeyVault/vaults/depa-inferencing-cin-kv
   
   terraform plan  # Verify the import
   terraform apply
   ```
   
   **Note**: The import command uses the Key Vault resource ID. After import, Terraform will only update
   `public_network_access_enabled` and `network_acls`, leaving other properties unchanged.

## What This Deployment Creates

- Private endpoint for Key Vault
- Private DNS zone for Key Vault
- DNS A records
- VNet links for private DNS zone
- **Disables public network access** on Key Vault (after private endpoint is configured)

## Resource Discovery

This deployment uses data sources to discover:
- Resource group
- Key Vault
- Virtual Network
- Private endpoint subnet
- Application Gateway

## Key Vault Public Access

This deployment also **disables public network access** on the Key Vault after the private endpoint is configured. Since the Key Vault is managed by the first deployment, you need to import it into this state:

```bash
terraform import azurerm_key_vault.disable_public_access /subscriptions/2a5f1e30-b076-4cb2-9235-2036241dedf0/resourceGroups/depa-inferencing-kms-prod-cin-rg/providers/Microsoft.KeyVault/vaults/depa-inferencing-cin-kv
```

After import, Terraform will only manage `public_network_access_enabled` and `network_acls` properties, leaving all other properties unchanged (via lifecycle ignore_changes).

