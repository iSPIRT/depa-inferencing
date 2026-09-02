#!/usr/bin/env bash
# Extract the native GCP `invoke` binary and its libcddl.so out of the GCP
# secure_invoke image into the package's native/ dir so the SDK's native backend
# (used for GCP gRPC) works and can be bundled into the wheel.
#
# The GCP services are built from a different fork than Azure and ship only the
# monolithic `invoke` tool (no C-ABI shared library), so the SDK drives that
# binary as a subprocess for GCP. This script vendors it locally.
#
# Usage:
#   scripts/fetch_native.sh [IMAGE]
#
# IMAGE defaults to the pinned GCP secure_invoke image.
set -euo pipefail

IMAGE="${1:-ispirt.azurecr.io/depainferencing/gcp/secure_invoke:4.10.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="${SCRIPT_DIR}/../src/depa_secure_invoke/native"

echo "Extracting native invoke binary from: ${IMAGE}"
mkdir -p "${NATIVE_DIR}/bin" "${NATIVE_DIR}/lib"

# docker cp needs a (stopped) container; create one without running it.
cid="$(docker create "${IMAGE}")"
trap 'docker rm -f "${cid}" >/dev/null 2>&1 || true' EXIT

docker cp "${cid}:/secure_invoke/invoke" "${NATIVE_DIR}/bin/invoke"
docker cp "${cid}:/usr/lib/libcddl.so" "${NATIVE_DIR}/lib/libcddl.so"

chmod +x "${NATIVE_DIR}/bin/invoke"

echo "Done. Native artifacts:"
ls -la "${NATIVE_DIR}/bin/invoke" "${NATIVE_DIR}/lib/libcddl.so"
