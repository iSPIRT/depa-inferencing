#!/usr/bin/env bash
# Deletes the orphaned KMS logs storage account (depainfkmsprodcinlogs).
# This account was removed from Terraform; Terraform no longer manages or deletes it.
set -e

STORAGE_ACCOUNT_NAME="${1:-depainfkmsprodcinlogs}"
RESOURCE_GROUP="${2:-depa-inferencing-kms-prod-cin-rg}"

echo "Deleting storage account: $STORAGE_ACCOUNT_NAME (resource group: $RESOURCE_GROUP)"
az storage account delete \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --yes

echo "Done. Storage account $STORAGE_ACCOUNT_NAME has been deleted."
