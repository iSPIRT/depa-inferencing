#!/usr/bin/env bash
# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.
#
# certbot --manual-auth-hook for the KMS frontend cert renewal workflow.
# Uploads the HTTP-01 challenge token into the $web container of the
# per-environment private storage account. The Application Gateway exposes
# /.well-known/acme-challenge/* by routing to that storage's static website
# endpoint over a private endpoint.
#
# Inputs (env):
#   STORAGE_ACCOUNT     - storage account name (set by the workflow)
#   CERTBOT_TOKEN       - challenge filename (set by certbot)
#   CERTBOT_VALIDATION  - response body certbot expects (set by certbot)

set -euo pipefail

: "${STORAGE_ACCOUNT:?STORAGE_ACCOUNT must be set}"
: "${CERTBOT_TOKEN:?CERTBOT_TOKEN must be set by certbot}"
: "${CERTBOT_VALIDATION:?CERTBOT_VALIDATION must be set by certbot}"

az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container '$web' \
  --name ".well-known/acme-challenge/$CERTBOT_TOKEN" \
  --data "$CERTBOT_VALIDATION" \
  --content-type text/plain \
  --auth-mode login \
  --overwrite \
  --only-show-errors

# Give the storage front-end a moment to make the new blob visible before
# Let's Encrypt fetches it.
sleep 10
