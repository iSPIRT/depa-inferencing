#!/bin/bash
# Script to temporarily enable Key Vault public network access for Terraform operations
# Usage: ./fix-keyvault-access.sh <resource-group-name> <key-vault-name>

set -e

RESOURCE_GROUP="${1:-depa-inferencing-kms-prod-cin-rg}"
KEY_VAULT_NAME="${2:-depa-inferencing-cin-kv}"

echo "Getting your current public IP address..."
MY_IP=$(curl -s ifconfig.me || curl -s https://api.ipify.org)
echo "Your IP address: $MY_IP"

echo ""
echo "Temporarily enabling public network access for Key Vault: $KEY_VAULT_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# Enable public network access
az keyvault update \
  --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --public-network-access Enabled \
  --output table

# Add current IP to network rules
echo "Adding your IP address to network rules..."
az keyvault network-rule add \
  --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --ip-address "$MY_IP/32" \
  --output table

# Set default action to Allow and bypass Azure Services
az keyvault update \
  --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --default-action Allow \
  --bypass AzureServices \
  --output table

echo ""
echo "✓ Public network access enabled. You can now run Terraform."
echo ""
echo "After Terraform completes, run this to disable public access again:"
echo "  az keyvault update --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --public-network-access Disabled"

