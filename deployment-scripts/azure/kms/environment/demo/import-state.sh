#!/usr/bin/env bash
# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.
#
# Import existing Azure resources into Terraform state for the phased KMS deployment.
#
# Prerequisites:
#   - az login (authenticated to the correct subscription)
#   - terraform init has been run in each deployment directory
#
# Usage:
#   1. Fill in SUBSCRIPTION_ID and TENANT_ID below.
#   2. Run: bash import-state.sh
#
# The script auto-discovers MI_PRINCIPAL_ID and ADMIN_PRINCIPAL_ID from Azure.
#
# The script is idempotent — re-running it will fail harmlessly on already-imported resources.

set -euo pipefail

# ============================================================================
# CONFIGURATION — Fill these in before running
# ============================================================================

SUBSCRIPTION_ID="<your_subscription_id>"
TENANT_ID="<your_tenant_id>"

# Resource names (these match the naming convention in the Terraform code)
ENVIRONMENT="prod"
REGION_SHORT="cin"
RG_NAME="depa-inferencing-kms-${ENVIRONMENT}-${REGION_SHORT}-rg"
MI_NAME="depa-inferencing-kms-${REGION_SHORT}-mi"
VNET_NAME="depa-inferencing-kms-${ENVIRONMENT}-${REGION_SHORT}-vnet"
KV_NAME="depa-inferencing-${REGION_SHORT}-kv"
CERT_NAME="depa-inferencing-kms-${ENVIRONMENT}-${REGION_SHORT}-member-cert"
LEDGER_NAME="depa-inferencing-kms-${ENVIRONMENT}-${REGION_SHORT}"
AGW_NAME="depa-inferencing-kms-${ENVIRONMENT}-${REGION_SHORT}-agw"

# Principal IDs for Key Vault role assignments (auto-discovered)
MI_PRINCIPAL_ID=$(az identity show --name "$MI_NAME" --resource-group "$RG_NAME" --query principalId -o tsv)
echo "Discovered MI_PRINCIPAL_ID: ${MI_PRINCIPAL_ID}"

# The admin principal ID — the currently signed-in user/SP.
# This matches the Terraform default: data.azurerm_client_config.current.object_id
ADMIN_PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null \
  || az account show --query "user.name" -o tsv | xargs -I{} az ad sp show --id {} --query id -o tsv 2>/dev/null \
  || { echo "ERROR: Could not determine admin principal ID. Set ADMIN_PRINCIPAL_ID manually."; exit 1; })
echo "Discovered ADMIN_PRINCIPAL_ID: ${ADMIN_PRINCIPAL_ID}"

# VM VNet configuration (for key-vault-networking)
VM_VNET_RG="depa-inferencing-prod"
VM_VNET_NAME="vnet-depainf-cicd"
VM_SUBNET_NAME="snet-depainf-cicd"

# Diagnostics workspace name (used in app gateway diagnostic setting name)
DIAGNOSTICS_SETTING_NAME="${AGW_NAME}-diagnostics"

# ============================================================================
# Helper
# ============================================================================

SUB_PREFIX="/subscriptions/${SUBSCRIPTION_ID}"
RG_PREFIX="${SUB_PREFIX}/resourceGroups/${RG_NAME}"

import() {
  local dir="$1"
  local addr="$2"
  local id="$3"
  echo "  Importing: ${addr}"
  (cd "$dir" && terraform import "$addr" "$id") || echo "  WARNING: import failed for ${addr} (may already exist in state)"
}

# ============================================================================
# PHASE 1: terraform/
# Resources: RG, Managed Identity, Federated Credential, Role Assignment,
#            VNet, DDoS Plan, Subnets, Key Vault, KV Role Assignments,
#            KV Certificate, Confidential Ledger
# ============================================================================

echo ""
echo "=============================="
echo "Phase 1: terraform/"
echo "=============================="

DIR="terraform"
(cd "$DIR" && terraform init)

# Resource Group
import "$DIR" \
  'module.kms.module.resource_group.azurerm_resource_group.this' \
  "${RG_PREFIX}"

# Managed Identity
import "$DIR" \
  'module.kms.module.managed_identity.azurerm_user_assigned_identity.this' \
  "${RG_PREFIX}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${MI_NAME}"

# Federated Identity Credential (for GitHub Actions)
import "$DIR" \
  'module.kms.module.managed_identity.azurerm_federated_identity_credential.github_actions[0]' \
  "${RG_PREFIX}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${MI_NAME}/federatedIdentityCredentials/${MI_NAME}-github-actions"

# Role Assignment: Managed Identity -> RG Contributor
RG_CONTRIBUTOR_ID=$(az role assignment list --scope "${RG_PREFIX}" --assignee "${MI_PRINCIPAL_ID}" --role "Contributor" --query "[0].id" -o tsv)
if [ -n "$RG_CONTRIBUTOR_ID" ]; then
  import "$DIR" \
    'module.kms.azurerm_role_assignment.managed_identity_rg_contributor' \
    "${RG_CONTRIBUTOR_ID}"
else
  echo "  WARNING: Could not find RG Contributor role assignment for MI. Skipping."
fi

# DDoS Protection Plan
import "$DIR" \
  'module.kms.module.virtual_network.azurerm_network_ddos_protection_plan.this' \
  "${RG_PREFIX}/providers/Microsoft.Network/ddosProtectionPlans/${VNET_NAME}-ddos-plan"

# Virtual Network
import "$DIR" \
  'module.kms.module.virtual_network.azurerm_virtual_network.this' \
  "${RG_PREFIX}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}"

# Gateway Subnet
import "$DIR" \
  'module.kms.module.virtual_network.azurerm_subnet.gateway' \
  "${RG_PREFIX}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${VNET_NAME}-gateway-subnet"

# Private Endpoint Subnet
import "$DIR" \
  'module.kms.module.virtual_network.azurerm_subnet.private_endpoint' \
  "${RG_PREFIX}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${VNET_NAME}-private-endpoint-subnet"

# Key Vault
import "$DIR" \
  'module.kms.module.key_vault.azurerm_key_vault.this' \
  "${RG_PREFIX}/providers/Microsoft.KeyVault/vaults/${KV_NAME}"

# Key Vault Role Assignments (auto-discovered)
KV_SCOPE="${RG_PREFIX}/providers/Microsoft.KeyVault/vaults/${KV_NAME}"

import_kv_role() {
  local addr="$1"
  local principal="$2"
  local role="$3"
  local role_id
  role_id=$(az role assignment list --scope "${KV_SCOPE}" --assignee "${principal}" --role "${role}" --query "[0].id" -o tsv)
  if [ -n "$role_id" ]; then
    import "$DIR" "$addr" "$role_id"
  else
    echo "  WARNING: Could not find '${role}' assignment for principal ${principal}. Skipping."
  fi
}

import_kv_role 'module.kms.module.key_vault.azurerm_role_assignment.admin[0]'               "$ADMIN_PRINCIPAL_ID" "Key Vault Administrator"
import_kv_role 'module.kms.module.key_vault.azurerm_role_assignment.crypto_user[0]'          "$MI_PRINCIPAL_ID"    "Key Vault Crypto User"
import_kv_role 'module.kms.module.key_vault.azurerm_role_assignment.crypto_officer[0]'       "$MI_PRINCIPAL_ID"    "Key Vault Crypto Officer"
import_kv_role 'module.kms.module.key_vault.azurerm_role_assignment.certificates_officer[0]' "$MI_PRINCIPAL_ID"    "Key Vault Certificates Officer"
import_kv_role 'module.kms.module.key_vault.azurerm_role_assignment.secrets_user[0]'         "$MI_PRINCIPAL_ID"    "Key Vault Secrets User"

# Key Vault Certificate (needs versioned URL)
CERT_VERSION=$(az keyvault certificate show --vault-name "${KV_NAME}" --name "${CERT_NAME}" --query "id" -o tsv)
if [ -n "$CERT_VERSION" ]; then
  import "$DIR" \
    'module.kms.module.key_vault.azurerm_key_vault_certificate.member' \
    "${CERT_VERSION}"
else
  echo "  WARNING: Could not find certificate ${CERT_NAME} in ${KV_NAME}. Skipping."
fi

# Confidential Ledger
import "$DIR" \
  'module.kms.module.confidential_ledger.azurerm_confidential_ledger.this' \
  "${RG_PREFIX}/providers/Microsoft.ConfidentialLedger/ledgers/${LEDGER_NAME}"

echo ""
echo "Phase 1 import complete. Run 'cd ${DIR} && terraform plan' to verify."

# ============================================================================
# PHASE 2: terraform-key-vault-networking/
# Resources: KV Private DNS Zone, VNet Links, Private Endpoints, A Record,
#            Key Vault (disable_public_access)
# ============================================================================

echo ""
echo "=============================="
echo "Phase 2: terraform-key-vault-networking/"
echo "=============================="

DIR="terraform-key-vault-networking"
(cd "$DIR" && terraform init)

# Private DNS Zone
import "$DIR" \
  'module.key_vault_networking.azurerm_private_dns_zone.key_vault' \
  "${RG_PREFIX}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"

# VNet Link (KMS VNet)
import "$DIR" \
  'module.key_vault_networking.azurerm_private_dns_zone_virtual_network_link.key_vault' \
  "${RG_PREFIX}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net/virtualNetworkLinks/${KV_NAME}-vnet-link"

# VNet Link (VM VNet)
import "$DIR" \
  'module.key_vault_networking.azurerm_private_dns_zone_virtual_network_link.key_vault_vm[0]' \
  "${RG_PREFIX}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net/virtualNetworkLinks/${KV_NAME}-vnet-link-vm"

# Private Endpoint (KMS VNet)
import "$DIR" \
  'module.key_vault_networking.azurerm_private_endpoint.key_vault' \
  "${RG_PREFIX}/providers/Microsoft.Network/privateEndpoints/${KV_NAME}-pe"

# Private Endpoint (VM VNet)
import "$DIR" \
  'module.key_vault_networking.azurerm_private_endpoint.key_vault_vm[0]' \
  "${RG_PREFIX}/providers/Microsoft.Network/privateEndpoints/${KV_NAME}-pe-vm"

# DNS A Record
import "$DIR" \
  'module.key_vault_networking.azurerm_private_dns_a_record.key_vault' \
  "${RG_PREFIX}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net/A/${KV_NAME}"

# Key Vault (disable_public_access) — the imported KV resource
import "$DIR" \
  'azurerm_key_vault.disable_public_access' \
  "${RG_PREFIX}/providers/Microsoft.KeyVault/vaults/${KV_NAME}"

echo ""
echo "Phase 2 import complete. Run 'cd ${DIR} && terraform plan' to verify."

# ============================================================================
# PHASE 3: terraform-application-gateway/
# Resources: Application Gateway, Public IP, WAF Policy, Diagnostic Setting
#            + Ledger Networking (PE, DNS Zone, VNet Link, A Record)
# ============================================================================

echo ""
echo "=============================="
echo "Phase 3: terraform-application-gateway/"
echo "=============================="

DIR="terraform-application-gateway"
(cd "$DIR" && terraform init)

# Application Gateway
import "$DIR" \
  'module.application_gateway.azurerm_application_gateway.this' \
  "${RG_PREFIX}/providers/Microsoft.Network/applicationGateways/${AGW_NAME}"

# Public IP
import "$DIR" \
  'module.application_gateway.azurerm_public_ip.gateway' \
  "${RG_PREFIX}/providers/Microsoft.Network/publicIPAddresses/${AGW_NAME}-pip"

# WAF Policy
import "$DIR" \
  'module.application_gateway.azurerm_web_application_firewall_policy.this' \
  "${RG_PREFIX}/providers/Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies/${AGW_NAME}-waf-policy"

# Diagnostic Setting (if diagnostics were configured)
import "$DIR" \
  'module.application_gateway.azurerm_monitor_diagnostic_setting.application_gateway[0]' \
  "${RG_PREFIX}/providers/Microsoft.Network/applicationGateways/${AGW_NAME}|${DIAGNOSTICS_SETTING_NAME}"

# Ledger Networking resources — these are NEW and may not exist yet.
# Only import these if they were already created in Azure.
echo ""
echo "  NOTE: Ledger networking resources (PE, DNS zone, A record, VNet link) are new."
echo "  If they don't exist yet in Azure, skip these imports — they will be created by terraform apply."
echo ""
echo "  If they do exist, import them:"
echo "    cd ${DIR} && terraform import 'module.ledger_networking.azurerm_private_dns_zone.ledger' '${RG_PREFIX}/providers/Microsoft.Network/privateDnsZones/confidential-ledger.azure.com'"
echo "    cd ${DIR} && terraform import 'module.ledger_networking.azurerm_private_dns_zone_virtual_network_link.ledger' '${RG_PREFIX}/providers/Microsoft.Network/privateDnsZones/confidential-ledger.azure.com/virtualNetworkLinks/${LEDGER_NAME}-vnet-link'"
echo "    cd ${DIR} && terraform import 'module.ledger_networking.azurerm_private_endpoint.ledger' '${RG_PREFIX}/providers/Microsoft.Network/privateEndpoints/${LEDGER_NAME}-pe'"
echo "    cd ${DIR} && terraform import 'module.ledger_networking.azurerm_private_dns_a_record.ledger' '${RG_PREFIX}/providers/Microsoft.Network/privateDnsZones/confidential-ledger.azure.com/A/${LEDGER_NAME}'"

echo ""
echo "Phase 3 import complete. Run 'cd ${DIR} && terraform plan' to verify."

echo ""
echo "=============================="
echo "All imports done."
echo "Run 'terraform plan' in each directory to verify no unexpected changes."
echo "=============================="
