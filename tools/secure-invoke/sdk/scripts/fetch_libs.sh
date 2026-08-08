#!/usr/bin/env bash
# Fetch the SDK's heavy binary dependencies from the container registry.
#
# These are stored as a single OCI artifact (pushed by publish_libs.sh) instead
# of being committed to git (~120 MB total). The registry allows anonymous pull,
# so NO credentials are needed here -- just ORAS.
#
#   * lib/libsecure_invoke.so + lib/libcddl.so  -> Azure REST (python backend)
#   * native/bin/invoke + native/lib/libcddl.so -> GCP gRPC   (native backend)
#
# Usage:
#   scripts/fetch_libs.sh [REF]
#
# REF defaults to $SECURE_INVOKE_LIBS_REF or the pinned artifact below.
set -euo pipefail

REF="${1:-${SECURE_INVOKE_LIBS_REF:-ispirt.azurecr.io/depainferencing/tools/secure_invoke_sdk_libs:1.0.0}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "${SCRIPT_DIR}/../src" && pwd)"

command -v oras >/dev/null 2>&1 || {
  echo "error: 'oras' not found. Install it: https://oras.land/docs/installation" >&2
  exit 1
}

echo "Fetching secure-invoke libraries from: ${REF}"
# Files are stored with paths relative to src/, so pull recreates the package
# tree (depa_secure_invoke/lib/... and depa_secure_invoke/native/...).
oras pull "${REF}" --output "${SRC_DIR}"

# ORAS does not preserve the executable bit; the native tool must be runnable.
NATIVE_BIN="${SRC_DIR}/depa_secure_invoke/native/bin/invoke"
[ -f "${NATIVE_BIN}" ] && chmod +x "${NATIVE_BIN}"

echo "Done. Vendored binaries:"
find "${SRC_DIR}/depa_secure_invoke/lib" "${SRC_DIR}/depa_secure_invoke/native" \
  -type f 2>/dev/null | sort
