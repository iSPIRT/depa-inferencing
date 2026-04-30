#!/usr/bin/env python3

# CI helper: run secure invoke against CCR and KMS on Azure using the secure_request wheel.

from __future__ import annotations

import os
import sys

from secure_request_client.cli import SecureRequestClient, SecureRequestConfig
from secure_request_client.kms_client import KMSClientError

_DEFAULT_CI_UA = "depa-github-actions-secure-invoke/1.0"

class AzureCiSecureRequestClient(SecureRequestClient):
    """KMS paths and headers suited for DEPA KMS behind OWASP CRS on App Gateway."""

    def setup_kms_client(self) -> bool:
        if not super().setup_kms_client():
            return False
        ua = os.environ.get("SECURE_REQUEST_USER_AGENT", _DEFAULT_CI_UA)
        self.kms_client.session.headers["User-Agent"] = ua
        return True

    def fetch_public_key(self):
        try:
            self.log("Fetching public key from KMS...")
            keys = self.kms_client.list_public_keys(endpoint="/app/listpubkeys")
            if not keys:
                print("✗ No keys found from KMS")
                return None

            selected_key = keys[0]
            self.log(f"✓ Selected key ID: {selected_key['key_id']}")
            return selected_key

        except KMSClientError as e:
            print(f"✗ KMS error: {e}")
            return None
        except Exception as e:
            print(f"✗ Unexpected error fetching keys: {e}")
            return None


def main() -> int:
    request_path = (
        sys.argv[1]
        if len(sys.argv) > 1
        else os.environ.get("REQUEST_JSON_PATH", "")
    ).strip()
    if not request_path:
        print(
            "Usage: run_azure_test_python_sdk.py <path-to-request.json>",
            file=sys.stderr,
        )
        return 1

    kms_url = os.environ.get("KMS_URL", "").rstrip("/")
    offer_url = os.environ.get("OFFER_URL", "").strip()
    if not kms_url or not offer_url:
        print("KMS_URL and OFFER_URL must be set.", file=sys.stderr)
        return 1

    config = SecureRequestConfig()
    # Base host only — path must use absolute /app/listpubkeys (see module doc).
    config.kms_host = kms_url
    config.offer_host = offer_url
    config.insecure = True
    config.request_payload = request_path
    config.retries = int(os.environ.get("SECURE_REQUEST_RETRIES", "3"))

    client = AzureCiSecureRequestClient(config)
    return 0 if client.run() else 1


if __name__ == "__main__":
    sys.exit(main())
