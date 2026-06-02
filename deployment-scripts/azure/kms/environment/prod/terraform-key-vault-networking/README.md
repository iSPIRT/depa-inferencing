# Key Vault Networking Deployment (Prod)

Separate Terraform deployment for Key Vault private endpoints, private DNS, and disabling public network access. Discovers existing Phase 1 resources via data sources.

## Prerequisites

Phase 1 resources must already exist in Azure ([`../terraform/`](../terraform/) is archive-only for prod — **do not apply Phase 1** in routine windows if live AGW/state differs).

**Before apply:** set `subscription_id`, `tenant_id`, and runner VNet fields in [`locals.tf`](locals.tf).

Terraform state for this phase is kept outside this repo (e.g. Drive).

Prod Key Vault name pattern: `depa-inferencing-<region_short>-kv` (see `key_vault_name` in locals; differs from UAT).

## Deployment order

1. Phase 1 resources exist in Azure (colleague baseline or prior apply).

2. From this directory:

   ```bash
   terraform init
   terraform plan
   ```

3. If the Key Vault is not yet in this phase’s state, import it (build the ID from [`locals.tf`](locals.tf)):

   ```bash
   # /subscriptions/<your_subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.KeyVault/vaults/<key_vault_name>

   terraform import azurerm_key_vault.disable_public_access \
     "/subscriptions/<your_subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.KeyVault/vaults/<key_vault_name>"
   ```

4. `terraform plan` then `terraform apply`.

After import, Terraform only updates `public_network_access_enabled` and `network_acls` on the vault (other attributes are lifecycle-ignored).

## What this deployment creates

- Private endpoint for Key Vault
- Private DNS zone for Key Vault
- DNS A records
- VNet links for the private DNS zone
- Runner VNet private endpoint when `vm_*` locals are set
- **Disables public network access** on Key Vault after private connectivity exists

## Resource discovery

Data sources resolve:

- Resource group
- Key Vault
- Virtual Network
- Private endpoint subnet
- Application Gateway
