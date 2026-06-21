#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${1:-secure_invoke_python:0.1.1}"
WHEEL_URL="${SECURE_REQUEST_WHEEL_URL:-https://github.com/saranggalada/bidding-auction-servers/releases/download/v0.1.0/secure_request-0.1.0-py3-none-any.whl}"

docker build \
  --build-arg "SECURE_REQUEST_WHEEL_URL=${WHEEL_URL}" \
  -t "${IMAGE}" \
  "${SCRIPT_DIR}"

echo "Built ${IMAGE}"
