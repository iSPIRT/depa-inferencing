#!/usr/bin/env bash
# Publish the SDK's heavy binary dependencies to the container registry as a
# single OCI artifact, so they don't have to live in git and can be pulled
# anonymously by scripts/fetch_libs.sh.
#
# This is a one-time (per version) provisioning step and REQUIRES push
# credentials. Log in first, e.g.:
#   az acr login --name ispirt        # or: oras login ispirt.azurecr.io -u .. -p ..
#
# Contents (paths are stored relative to src/):
#   * depa_secure_invoke/lib/libsecure_invoke.so + libcddl.so   (Azure fork)
#   * depa_secure_invoke/native/bin/invoke + native/lib/libcddl.so (GCP fork)
#
# Usage:
#   scripts/publish_libs.sh [REF] [GCP_SECURE_INVOKE_IMAGE]
set -euo pipefail

REF="${1:-${SECURE_INVOKE_LIBS_REF:-ispirt.azurecr.io/depainferencing/tools/secure_invoke_sdk_libs:1.0.0}}"
GCP_IMAGE="${2:-${GCP_SECURE_INVOKE_IMAGE:-ispirt.azurecr.io/depainferencing/gcp/secure_invoke:4.10.0}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "${SCRIPT_DIR}/../src" && pwd)"
PKG="depa_secure_invoke"

command -v oras >/dev/null 2>&1 || { echo "error: 'oras' not found." >&2; exit 1; }

# The GCP native binary is not committed either; pull it out of the GCP image if
# it isn't already vendored locally.
if [ ! -f "${SRC_DIR}/${PKG}/native/bin/invoke" ]; then
  echo "Native invoke binary missing locally; extracting from ${GCP_IMAGE}"
  "${SCRIPT_DIR}/fetch_native.sh" "${GCP_IMAGE}"
fi

required=(
  "${PKG}/lib/libsecure_invoke.so"
  "${PKG}/lib/libcddl.so"
  "${PKG}/native/bin/invoke"
  "${PKG}/native/lib/libcddl.so"
)
for f in "${required[@]}"; do
  [ -f "${SRC_DIR}/${f}" ] || { echo "error: missing ${SRC_DIR}/${f}" >&2; exit 1; }
done

echo "Publishing secure-invoke libraries to: ${REF}"
cd "${SRC_DIR}"
oras push "${REF}" \
  --artifact-type application/vnd.depa.secure-invoke.libs \
  "${required[@]}"

echo "Published ${REF}"
