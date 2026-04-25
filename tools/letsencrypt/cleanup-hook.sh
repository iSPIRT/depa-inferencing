#!/usr/bin/env bash
# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.
#
# certbot --manual-cleanup-hook for the KMS frontend cert renewal workflow.
# Removes the HTTP-01 challenge token uploaded by auth-hook.sh.

set -euo pipefail

: "${STORAGE_ACCOUNT:?STORAGE_ACCOUNT must be set}"
: "${CERTBOT_TOKEN:?CERTBOT_TOKEN must be set by certbot}"

az storage blob delete \
  --account-name "$STORAGE_ACCOUNT" \
  --container '$web' \
  --name ".well-known/acme-challenge/$CERTBOT_TOKEN" \
  --auth-mode login \
  --only-show-errors || true
