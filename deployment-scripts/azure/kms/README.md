# Key Management Service (KMS) Terraform Deployment

This directory contains Terraform configurations for deploying the Key Management Service (KMS) infrastructure on Azure. The KMS provides secure key management using Azure Key Vault, Confidential Ledger, and Application Gateway.

## Overview

The KMS deployment is split into three phases with a manual step in between. The phased design exists so that the Application Gateway can reach the Confidential Ledger over a **private endpoint** rather than the public ledger FQDN. Because Azure only exposes the ledger via a Private Link Service (PLS) that must be created out-of-band, the gateway cannot be provisioned in the same Terraform run as the ledger.

```
Phase 1: terraform/                        --> RG, MI, VNet, Key Vault, Confidential Ledger
Phase 2: terraform-key-vault-networking/   --> Key Vault private endpoint, disable public access
Manual:  Create Confidential Ledger PLS    --> Produces a PLS alias (out-of-band)
Phase 3: terraform-application-gateway/    --> Ledger private endpoint + DNS, Application Gateway
```

Each phase has its own Terraform state. Later phases discover resources from earlier phases through data sources.

## Directory Structure

```
kms/
├── environment/
│   └── demo/
│       ├── terraform/                           # Phase 1: ledger + dependencies
│       ├── terraform-key-vault-networking/      # Phase 2: KV private endpoint
│       ├── terraform-application-gateway/       # Phase 3: ledger PE + App Gateway
│       └── import-state.sh                      # Rebuilds state across all phases
├── modules/
│   └── kms/                                     # Phase 1 composite module
└── services/                                    # Reusable service modules
    ├── application_gateway/                     # Application Gateway (supports PIP reuse)
    ├── confidential_ledger/
    ├── key_vault/
    ├── key_vault_networking/
    ├── ledger_networking/                       # Ledger PE + private DNS zone
    ├── managed_identity/
    ├── resource_group/
    ├── storage_account/
    └── virtual_network/
```

## Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.0
- Azure CLI configured with appropriate credentials
- Access to the target Azure subscription and resource groups

## Deployment Process

### Phase 1: Ledger and Dependencies

Deploy the Confidential Ledger along with the resource group, managed identity, virtual network, and Key Vault.

```bash
cd environment/demo/terraform
terraform init
terraform plan
terraform apply
```

**What gets created:**
- Resource Group
- Managed Identity (with GitHub federated credentials)
- Virtual Network with `gateway` and `private-endpoint` subnets
- Key Vault (with public access enabled initially; certificate issued for the ledger)
- Confidential Ledger

No Application Gateway is created in this phase.

### Phase 2: Key Vault Networking

Configure the Key Vault private endpoint and disable public access:

```bash
cd ../terraform-key-vault-networking
terraform init
terraform plan

# Import the existing Key Vault so Terraform can flip public_network_access_enabled
terraform import azurerm_key_vault.disable_public_access \
  /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{vault-name}

terraform plan   # verify the import
terraform apply
```

**What gets created:**
- Private endpoint for Key Vault in the KMS VNet
- Optional private endpoint for an externally provisioned VM
- Private DNS zone `privatelink.vaultcore.azure.net` with A records
- VNet links for DNS resolution
- Key Vault public network access is set to **Disabled**

### Manual Step: Create the Confidential Ledger Private Link Service

Azure does not expose a Confidential Ledger PLS through Terraform. After Phase 1, create the PLS out-of-band (for example, via the Azure Portal's *Networking* blade on the ledger). Approve the PLS and capture its alias, which looks like:

```
depa-inferencing-kms-demo-cin-pls.{guid}.centralindia.azure.privatelinkservice
```

Record the alias; Phase 3 will not plan without it.

### Phase 3: Application Gateway

Set the PLS alias in `environment/demo/terraform-application-gateway/locals.tf`:

```hcl
ledger_private_link_service_alias = "depa-inferencing-kms-demo-cin-pls.{guid}.centralindia.azure.privatelinkservice"
```

Then deploy:

```bash
cd ../terraform-application-gateway
terraform init
terraform plan
terraform apply
```

**What gets created:**
- Private endpoint to the ledger PLS (manual connection, auto-approved on the PLS side)
- Private DNS zone `confidential-ledger.azure.com` with an A record that overrides the ledger's public FQDN so it resolves to the private endpoint IP inside the VNet
- VNet link for the DNS zone
- Application Gateway (WAF_v2) with the **same** ledger FQDN as the backend pool address (now resolved privately), SSL termination from Key Vault, and the ledger TLS certificate as trusted root
- Optionally reuses an existing public IP if `public_ip_id` is set in `locals.tf`

## Configuration

Each phase's `locals.tf` carries its own environment values. Replace placeholders such as `<your_subscription_id>` and `<your_tenant_id>` before running Terraform.

### Phase 1 (`terraform/kms.tf`)

- Environment, region, subscription, tenant
- GitHub repository and branch for managed identity federated credentials
- Certificate name issued in Key Vault for the ledger

### Phase 2 (`terraform-key-vault-networking/locals.tf`)

- Key Vault name (from Phase 1)
- Optional VM VNet configuration for an additional private endpoint
- Additional VNet IDs to link to the private DNS zone (without creating extra endpoints)

### Phase 3 (`terraform-application-gateway/locals.tf`)

- `ledger_private_link_service_alias` — **required**, from the manual step
- `ssl_certificate_name`, Key Vault name, managed identity name (from Phase 1)
- Log Analytics workspace for gateway diagnostics
- `allowed_hostname` for Host header validation
- Optional `public_ip_id` to reuse an existing public IP (preserves DNS-configured addresses)

## State Migration and Recovery

The repository includes [environment/demo/import-state.sh](environment/demo/import-state.sh) for rebuilding Terraform state from an existing Azure deployment. The script:

- Auto-discovers the managed identity principal ID and the caller's principal ID
- Auto-discovers role assignment IDs for the create-only role assignments
- Imports resources into the correct state for each phase (Phase 1, Phase 2, Phase 3)

Run it from a directory where `az account show` resolves to the target subscription. After running, `terraform plan` in each phase should report no drift (or only expected changes).

## Key Components

### Key Vault
- Stores SSL certificates and the ledger member certificate
- Phase 1 creates it with public access enabled so certificate issuance works
- Phase 2 replaces public access with a private endpoint
- Uses RBAC for authorization

### Confidential Ledger
- Tamper-proof audit log, Azure AD-authenticated
- Phase 1 provisions it; Phase 3 wires it behind a private endpoint
- Phase 3 fetches the ledger's TLS certificate via the Azure identity service and installs it as the gateway's trusted root

### Application Gateway
- WAF_v2, public HTTPS frontend, SSL terminated using a Key Vault certificate
- Backend pool uses the ledger's public FQDN; within the VNet this FQDN resolves to the private endpoint via the private DNS zone created in Phase 3
- Accesses Key Vault through its private endpoint using the shared user-assigned managed identity
- Supports reusing a pre-existing public IP via `public_ip_id`

### Private DNS Zones
- `privatelink.vaultcore.azure.net` (Phase 2) — Key Vault private resolution
- `confidential-ledger.azure.com` (Phase 3) — overrides the ledger's public zone inside the KMS VNet so the public FQDN resolves to the private endpoint IP

## Network Architecture

```
Internet
   │
   ▼
Application Gateway (Public IP, WAF_v2)
   │  backend = ledger FQDN (resolved privately via DNS override)
   ▼
Ledger Private Endpoint ──► Confidential Ledger (via PLS)
   │
Gateway ──► Key Vault Private Endpoint ──► Key Vault (public access disabled)
```

## Troubleshooting

### Phase 3 plan fails with an empty `request_message`

The ledger private endpoint uses `is_manual_connection = true` and therefore requires a non-empty `request_message`. The `services/ledger_networking` module sets this, so this error typically means a stale module version is cached — re-run `terraform init -upgrade`.

### Phase 3 errors with "Public IP cannot be changed"

Azure does not allow swapping the frontend public IP of an existing Application Gateway via update. Either destroy and recreate the gateway (downtime) or rename the existing public IP in Azure to match the name Terraform expects and re-run `terraform apply`.

### Role assignment "doesn't support update"

Azure role assignments are create-only. If `terraform plan` shows an update on an imported role assignment, confirm the attributes on the resource match reality (e.g., no `skip_service_principal_aad_check` drift) and remove any immutable attribute from configuration.

### Duplicate DNS Zone Link Error

If a private DNS zone is already linked to a VNet:

1. Check whether the VNet is listed in both `additional_virtual_network_ids` and has a private endpoint configured
2. Remove the VNet from `additional_virtual_network_ids` if a private endpoint is being created
3. Import or remove the existing link manually:

```bash
az network private-dns link vnet list \
  --resource-group {rg-name} \
  --zone-name privatelink.vaultcore.azure.net

az network private-dns link vnet delete \
  --resource-group {rg-name} \
  --zone-name privatelink.vaultcore.azure.net \
  --name {link-name}
```

### Key Vault Import Issues

If the Key Vault import fails, ensure the Key Vault resource ID is correct, you have appropriate permissions, and Phase 1 has completed.

### VM Cannot Access Key Vault

1. Verify the private endpoint is created in the correct subnet
2. Check that the DNS zone is linked to the VM's VNet
3. Ensure the VM's subnet allows outbound traffic to the private endpoint
4. Verify DNS resolution from the VM: `nslookup {key-vault-name}.vault.azure.net`

## Outputs

### Phase 1 (`terraform/`)
- Resource group name and ID
- Key Vault name, URI, and ID
- Confidential Ledger name and endpoint
- Managed Identity principal ID
- Virtual Network name and gateway/private-endpoint subnet IDs

### Phase 2 (`terraform-key-vault-networking/`)
- Private DNS zone ID and name
- Main private endpoint ID
- VM private endpoint ID (if configured)

### Phase 3 (`terraform-application-gateway/`)
- Application Gateway endpoint and public IP
- Ledger private endpoint ID
- Ledger private DNS zone ID and name

## Security Considerations

- Key Vault public access is disabled after Phase 2
- All Key Vault access goes through private endpoints
- Ledger access from the Application Gateway stays inside the VNet (Phase 3)
- Network ACLs are set to deny by default (Azure Services bypass enabled)
- Application Gateway uses a user-assigned managed identity to access Key Vault
- Confidential Ledger uses the same managed identity for AAD-based authentication

## Additional Resources

- [Key Vault Networking README](environment/demo/terraform-key-vault-networking/README.md) — Detailed guide for Phase 2
- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Azure Private Endpoints](https://docs.microsoft.com/azure/private-link/private-endpoint-overview)
- [Azure Private Link Service](https://docs.microsoft.com/azure/private-link/private-link-service-overview)
- [Confidential Ledger Documentation](https://docs.microsoft.com/azure/confidential-ledger/)
