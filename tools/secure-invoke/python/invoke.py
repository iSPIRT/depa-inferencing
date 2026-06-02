#!/usr/bin/env python3
"""
Secure invoke entrypoint for the Python SDK Docker image.

Reads configuration from environment variables compatible with the legacy
C++ secure-invoke container (KMS_HOST, BUYER_HOST, REQUEST_PATH, etc.).
"""

from __future__ import annotations

import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from secure_request_client import OfferRequestClient
from secure_request_client.cli import (
    SecureRequestClient,
    SecureRequestConfig,
    parse_headers,
    suppress_stdout,
)
from secure_request_client.kms_client import KMSClientError

_DEFAULT_USER_AGENT = "depa-secure-invoke-python/0.1.0"


def _env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    return int(raw)


def _env_float(name: str, default: float) -> float:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    return float(raw)


def _normalize_url(host: str, default_scheme: str) -> str:
    host = host.strip()
    if not host:
        return host
    if host.startswith(("http://", "https://")):
        return host
    return f"{default_scheme}://{host}"


def _optional_path(name: str) -> Optional[str]:
    value = os.environ.get(name, "").strip()
    if not value or value.endswith("/"):
        return None
    if not os.path.isfile(value):
        return None
    return value


class DepaSecureRequestClient(SecureRequestClient):
    """SecureRequestClient with configurable KMS list-keys path and User-Agent."""

    def __init__(self, config: SecureRequestConfig, kms_keys_endpoint: str):
        super().__init__(config)
        self.kms_keys_endpoint = kms_keys_endpoint

    def setup_kms_client(self) -> bool:
        if not super().setup_kms_client():
            return False
        ua = os.environ.get("SECURE_REQUEST_USER_AGENT", _DEFAULT_USER_AGENT)
        self.kms_client.session.headers["User-Agent"] = ua
        return True

    def fetch_public_key(self) -> Optional[Dict[str, Any]]:
        try:
            self.log("Fetching public key from KMS...")
            keys = self.kms_client.list_public_keys(endpoint=self.kms_keys_endpoint)
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


def build_config() -> Tuple[SecureRequestConfig, str]:
    kms_host = os.environ.get("KMS_HOST", "").strip()
    buyer_host = os.environ.get("BUYER_HOST", "").strip()
    request_path = os.environ.get("REQUEST_PATH", "/requests/get_bids_request.json").strip()

    if not kms_host:
        raise ValueError("KMS_HOST is required")
    if not buyer_host:
        raise ValueError("BUYER_HOST is required")
    if not request_path:
        raise ValueError("REQUEST_PATH is required")

    config = SecureRequestConfig()
    config.kms_host = _normalize_url(kms_host, "https")
    config.offer_host = _normalize_url(buyer_host, "http")
    config.request_payload = request_path
    config.retries = 1
    config.insecure = _env_bool("INSECURE", False)
    config.enable_verbose = _env_bool("ENABLE_VERBOSE", False)
    config.client_cert = _optional_path("CLIENT_CERT")
    config.client_key = _optional_path("CLIENT_KEY")
    config.ca_cert = _optional_path("CA_CERT")

    headers_raw = os.environ.get("HEADERS", "").strip()
    if headers_raw:
        config.headers = parse_headers(headers_raw)

    kms_keys_endpoint = os.environ.get("KMS_KEYS_ENDPOINT", "/listpubkeys").strip() or "/listpubkeys"
    return config, kms_keys_endpoint


def _create_client() -> DepaSecureRequestClient:
    config, kms_keys_endpoint = build_config()
    return DepaSecureRequestClient(config, kms_keys_endpoint)


def _prepare_client(client: DepaSecureRequestClient) -> Optional[Dict[str, Any]]:
    if not client.config.validate():
        return None
    if not client.setup_kms_client():
        return None

    public_key = client.fetch_public_key()
    if not public_key:
        return None
    return public_key


def run_rest_invoke() -> int:
    run_retries = max(1, _env_int("RUN_RETRIES", 1))
    run_retry_delay = _env_float("RUN_RETRY_DELAY", 5.0)

    for attempt in range(1, run_retries + 1):
        client = _create_client()
        if client.run():
            if attempt > 1:
                print(f"Succeeded on run attempt {attempt}/{run_retries}", file=sys.stderr)
            return 0

        if attempt < run_retries:
            print(
                f"Run failed (attempt {attempt}/{run_retries}), "
                f"retrying in {run_retry_delay:g}s...",
                file=sys.stderr,
            )
            time.sleep(run_retry_delay)

    return 1


def run_encrypt() -> int:
    client = _create_client()
    public_key = _prepare_client(client)
    if not public_key:
        return 1

    request_data = client.load_request_data()
    if request_data is None:
        return 1

    try:
        crypto_client = OfferRequestClient(
            public_key=public_key["public_key"],
            key_id=public_key["key_id"],
        )
        if client.config.enable_verbose:
            encryption_result = crypto_client.encrypt_offer_request(request_data)
        else:
            with suppress_stdout():
                encryption_result = crypto_client.encrypt_offer_request(request_data)
    except Exception as exc:
        print(f"✗ Error encrypting request: {exc}")
        return 1

    print(encryption_result.encrypted_data)
    return 0


def _load_batch_requests(path: Path) -> List[Tuple[int, Dict[str, Any]]]:
    requests: List[Tuple[int, Dict[str, Any]]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            payload = json.loads(line)
            if not isinstance(payload, dict):
                raise ValueError(f"Line {line_no}: expected a JSON object")
            request_id = payload.get("id")
            if request_id is None:
                raise ValueError(f"Line {line_no}: missing required 'id' field")
            request_body = payload.get("request", payload)
            requests.append((int(request_id), request_body))
    return requests


def _process_batch_item(
    public_key: Dict[str, Any],
    request_id: int,
    request_data: Dict[str, Any],
) -> Tuple[int, Optional[Dict[str, Any]], Optional[str]]:
    try:
        worker = _create_client()
        if not worker.config.validate():
            return request_id, None, "Invalid configuration"
        if not worker.setup_kms_client():
            return request_id, None, "Failed to setup KMS client"
        if not worker.setup_http_client():
            return request_id, None, "Failed to setup HTTP client"

        result = worker.process_single_request(request_data, public_key)
        if result is None:
            return request_id, None, "Request processing failed"
        return request_id, result, None
    except Exception as exc:
        return request_id, None, str(exc)


def run_batch_invoke() -> int:
    bootstrap = _create_client()
    public_key = _prepare_client(bootstrap)
    if not public_key:
        return 1

    client = bootstrap

    request_path = Path(client.config.request_payload)
    if not request_path.exists():
        print(f"✗ Error: Request file not found: {request_path}", file=sys.stderr)
        return 1

    try:
        batch_requests = _load_batch_requests(request_path)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"✗ Error loading batch file: {exc}", file=sys.stderr)
        return 1

    if not batch_requests:
        print("✗ Error: Batch file is empty", file=sys.stderr)
        return 1

    max_workers = max(1, _env_int("MAX_CONCURRENT_REQUESTS", 2))
    successes: List[Dict[str, Any]] = []
    failures: List[Dict[str, Any]] = []

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(_process_batch_item, public_key, request_id, request_data): request_id
            for request_id, request_data in batch_requests
        }
        for future in as_completed(futures):
            request_id, response, error = future.result()
            if error:
                failures.append({"id": request_id, "error": {"message": error}})
            else:
                successes.append({"id": request_id, "response": response})

    output_dir = request_path.parent
    success_path = output_dir / "success_log.jsonl"
    failure_path = output_dir / "failure_log.jsonl"

    with success_path.open("w", encoding="utf-8") as handle:
        for item in sorted(successes, key=lambda row: row["id"]):
            handle.write(json.dumps(item) + "\n")

    with failure_path.open("w", encoding="utf-8") as handle:
        for item in sorted(failures, key=lambda row: row["id"]):
            handle.write(json.dumps(item) + "\n")

    print(f"Batch complete: {len(successes)} succeeded, {len(failures)} failed")
    print(f"  Success log: {success_path}")
    print(f"  Failure log: {failure_path}")
    return 0 if not failures else 1


def main() -> int:
    operation = os.environ.get("OPERATION", "rest_invoke").strip().lower()

    if operation in {"rest_invoke", "invoke"}:
        return run_rest_invoke()
    if operation in {"encrypt", "encrypt_payload"}:
        return run_encrypt()
    if operation == "batch_invoke":
        return run_batch_invoke()

    print(
        f"✗ Unsupported OPERATION '{operation}'. "
        "Supported: rest_invoke, encrypt, batch_invoke",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError as exc:
        print(f"✗ Configuration error: {exc}", file=sys.stderr)
        sys.exit(1)
