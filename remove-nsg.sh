#!/bin/bash
# Script to remove NSG association and resources
# This must be done before Terraform can delete the NSG rules

set -e

RESOURCE_GROUP="${1:-depa-inferencing-kms-prod-cin-rg}"
VNET_NAME="${2:-depa-inferencing-kms-prod-cin-vnet}"
SUBNET_NAME="${3:-depa-inferencing-kms-prod-cin-vnet-gateway-subnet}"
NSG_NAME="${4:-depa-inferencing-kms-prod-cin-vnet-gateway-nsg}"

echo "Removing NSG association from subnet..."
echo "Resource Group: $RESOURCE_GROUP"
echo "VNet: $VNET_NAME"
echo "Subnet: $SUBNET_NAME"
echo "NSG: $NSG_NAME"
echo ""

# Remove NSG association from subnet using Azure REST API
# The CLI doesn't support removing NSG directly, so we use REST API
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "Getting current subnet configuration..."
SUBNET_JSON=$(az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  -o json)

# Extract address prefix (could be addressPrefix or addressPrefixes)
ADDRESS_PREFIX=$(echo "$SUBNET_JSON" | jq -r '.addressPrefix // .addressPrefixes[0] // empty')

# Build the request body, preserving existing properties but removing NSG
REQUEST_BODY=$(echo "$SUBNET_JSON" | jq '{
  properties: {
    addressPrefix: .addressPrefix,
    addressPrefixes: .addressPrefixes,
    networkSecurityGroup: null,
    routeTable: .routeTable,
    serviceEndpoints: .serviceEndpoints,
    delegations: .delegations,
    privateEndpointNetworkPolicies: .privateEndpointNetworkPolicies,
    privateLinkServiceNetworkPolicies: .privateLinkServiceNetworkPolicies
  }
}')

echo "Removing NSG association via REST API..."

az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME?api-version=2023-05-01" \
  --body "$REQUEST_BODY" \
  --output table

echo ""
echo "✓ NSG association removed from subnet."
echo ""
echo "Now you can run Terraform to delete the NSG rules and NSG itself."
echo "The NSG rules should delete successfully now that the association is removed."

