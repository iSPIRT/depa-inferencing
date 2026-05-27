#!/bin/bash

# Usage: ./update_policies_tf.sh [nonprod]
# If nonprod is passed, the policies will be updated for the nonprod environment.
# Otherwise, the policies will be updated for the prod environment.
#
# Requires az confcom version in confcom.version (same as CI workflows).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFCOM_VERSION="$(tr -d '[:space:]' < "$SCRIPT_DIR/confcom.version")"
REPO_ROOT=$(git rev-parse --show-toplevel)
POLICIES_DIR=$REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies

installed=$(az extension list --query "[?name=='confcom'].version | [0]" -o tsv 2>/dev/null || true)
if [ "$installed" != "$CONFCOM_VERSION" ]; then
  echo "Installing confcom ${CONFCOM_VERSION} (found: ${installed:-none})..."
  az extension remove --name confcom 2>/dev/null || true
  az extension add --name confcom --version "$CONFCOM_VERSION"
fi

cd "$SCRIPT_DIR"

az confcom acipolicygen -y -i kv-policy.json --print-policy | grep -v '^$' > \
    $POLICIES_DIR/kv.base64
az confcom acipolicygen -y -i ofe-policy.json --print-policy | grep -v '^$' > \
    $POLICIES_DIR/ofe.base64
az confcom acipolicygen -y -i offer-policy.json --print-policy | grep -v '^$' > \
    $POLICIES_DIR/offer.base64

cat $POLICIES_DIR/kv.base64 | base64 -d | sha256sum | cut -d' ' -f1
cat $POLICIES_DIR/ofe.base64 | base64 -d | sha256sum | cut -d' ' -f1
cat $POLICIES_DIR/offer.base64 | base64 -d | sha256sum | cut -d' ' -f1

if [[ "${1:-}" == "nonprod" ]]; then
  PROD_KMS_URL="https://depa-inferencing-kms-azure.ispirt.in"
  UAT_KMS_URL="https://depa-inferencing-kms-uat-azure.ispirt.in"
  NONPROD_DIR="$POLICIES_DIR/nonprod"
  mkdir -p "$NONPROD_DIR"
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  for policy in kv-policy.json ofe-policy.json offer-policy.json; do
    base="${policy%-policy.json}"
    nonprod_json="$TMP_DIR/$policy"
    sed \
      -e 's/:prod-/:nonprod-/g' \
      -e "s|${PROD_KMS_URL}|${UAT_KMS_URL}|g" \
      "$policy" > "$nonprod_json"
    az confcom acipolicygen -y -i "$nonprod_json" --print-policy | grep -v '^$' > \
        "$NONPROD_DIR/${base}.base64"
    cat "$NONPROD_DIR/${base}.base64" | base64 -d | sha256sum | cut -d' ' -f1
  done
fi
