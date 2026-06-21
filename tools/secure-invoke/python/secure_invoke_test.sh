#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

if [[ -f "${REPO_ROOT}/.env" ]]; then
  set -o allexport
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.env"
  set +o allexport
fi

echo "Starting secure-invoke Python container with the following settings:"
echo "  Host Requests Directory: ${HOST_REQUESTS_DIR:-}"
echo "  KMS Host: ${KMS_HOST:-}"
echo "  Buyer Host: ${BUYER_HOST:-}"
echo "  Operation: ${OPERATION:-rest_invoke}"
echo "  Request Path: ${REQUEST_PATH:-/requests/get_bids_request.json}"
echo "  Run retries: ${RUN_RETRIES:-3}"
echo "  HEADERS: ${HEADERS:-}"
echo "  Insecure Mode: ${INSECURE:-true}"
echo "  Host Certs Directory: ${HOST_CERTS_DIR:-}"
echo "  client_key file: ${CLIENT_KEY:-}"
echo "  client_cert file: ${CLIENT_CERT:-}"
echo "  ca_cert file: ${CA_CERT:-}"
echo "  enable_verbose: ${ENABLE_VERBOSE:-false}"
echo "  kms_keys_endpoint: ${KMS_KEYS_ENDPOINT:-/listpubkeys}"

docker compose -f "${REPO_ROOT}/docker-compose.yml" up --exit-code-from secure-invoke-python secure-invoke-python
