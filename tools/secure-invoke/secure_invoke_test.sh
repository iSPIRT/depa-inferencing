#!/bin/bash

set -e

export REPO_ROOT=$(realpath $(dirname "${BASH_SOURCE[0]}"))

# Load environment variables from .env file if it exists
if [ -f "$REPO_ROOT/.env" ]; then
    set -o allexport
    source "$REPO_ROOT/.env"
    set +o allexport
fi


echo "Starting secure-invoke container with the following settings:"
echo "  Host Requests DIR: $HOST_REQUESTS_DIR"
echo "  KMS Host: $KMS_HOST"
echo "  Buyer Host: $BUYER_HOST"
echo "  Operation: $OPERATION"
echo "  Retries: $RETRIES"
echo "  Target Service: $TARGET_SERVICE"
echo "  HEADERS: $HEADERS"
echo "  Insecure Mode: $insecure"
echo "  Host Certs DIR: $HOST_CERTS_DIR"
echo "  client_key file: $CLIENT_KEY"
echo "  client_cert file: $CLIENT_CERT"
echo "  ca_cert file: $CA_CERT"
echo "  enable_verbose: ${ENABLE_VERBOSE:-false}"

docker compose -f "$REPO_ROOT/docker-compose.yml" up secure-invoke
