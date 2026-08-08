#!/usr/bin/env bash
# Build the secure-invoke SDK Docker image (self-contained: Azure REST + GCP gRPC).
# The crypto binaries are pulled from the registry (anonymous) at build time; see
# scripts/publish_libs.sh for how they get there.
#
#   ./docker/build.sh [image[:tag]] [secure_invoke_libs_ref]
set -euo pipefail

IMAGE="${1:-ispirt.azurecr.io/depainferencing/tools/secure_invoke_sdk:1.0.0}"
LIBS_REF="${2:-ispirt.azurecr.io/depainferencing/tools/secure_invoke_sdk_libs:1.0.0}"
SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker build \
    -f "${SDK_ROOT}/docker/Dockerfile" \
    --build-arg "SECURE_INVOKE_LIBS_REF=${LIBS_REF}" \
    -t "${IMAGE}" \
    "${SDK_ROOT}"
echo "Built ${IMAGE}"
