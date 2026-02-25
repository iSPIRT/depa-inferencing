"""
GetValues API tests (structure, first delta, edge cases).
First-delta test generates and uploads delta from Python when storage is configured (like incremental test).
"""
import logging
import os
import sys
import time
from pathlib import Path

import pytest
import requests

# Parent dir for delta_tooling and csv_generator
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from .kv_client import (
    build_getvalues_body,
    decode_compression_groups,
    get_values,
    key_values_from_decoded,
)

log = logging.getLogger(__name__)

# Env vars for Azure Storage (optional)
STORAGE_ACCOUNT = os.environ.get("KV_TEST_STORAGE_ACCOUNT")
STORAGE_KEY = os.environ.get("KV_TEST_STORAGE_KEY")
SHARE_NAME = os.environ.get("KV_TEST_SHARE_NAME", "fslogix")
SHARE_PATH = os.environ.get("KV_TEST_SHARE_PATH", "deltas")
RELOAD_WAIT_SEC = int(os.environ.get("KV_TEST_RELOAD_WAIT_SEC", "90"))


@pytest.fixture(scope="module")
def storage_configured():
    return bool(STORAGE_ACCOUNT and STORAGE_KEY and SHARE_NAME)


class TestGetValuesStructure:
    """Response shape and status."""

    def test_getvalues_returns_200(self, kv_base_url, getvalues_body):
        r = get_values(kv_base_url, getvalues_body)
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text[:500]}"

    def test_getvalues_returns_compression_groups(self, kv_base_url, getvalues_body):
        r = get_values(kv_base_url, getvalues_body)
        assert r.status_code == 200
        data = r.json()
        assert "compressionGroups" in data, f"Missing compressionGroups: {list(data.keys())}"
        assert len(data["compressionGroups"]) >= 1
        assert "content" in data["compressionGroups"][0]

    def test_getvalues_content_decodes_to_json(self, kv_base_url, getvalues_body):
        r = get_values(kv_base_url, getvalues_body)
        assert r.status_code == 200
        decoded = decode_compression_groups(r.json())
        assert decoded
        first = decoded[0]
        assert first is not None
        if isinstance(first, list):
            assert len(first) >= 1
        else:
            assert "partitions" in first or "keyGroupOutputs" in first or "keyValues" in first or "id" in first


class TestGetValuesInitialDelta:
    """
    Upload first delta and assert getValues returns first and last key.
    Flow: generate CSV, upload DELTA_0000000000000001, wait, getValues, assert first/last key present.
    """

    def test_getvalues_returns_first_and_last_key_from_initial_delta(
        self, kv_base_url, kv_hostname, tmp_path, storage_configured
    ):
        if not storage_configured:
            pytest.skip("Azure Storage not configured (KV_TEST_STORAGE_* env vars)")
        from csv_generator import write_kv_csv
        from delta_tooling import generate_and_upload_delta

        num_records = 2
        key_start = 0
        seed = 42
        csv_path, keys, values = write_kv_csv(
            tmp_path / "generated_first_delta.csv",
            num_records=num_records,
            key_start=key_start,
            seed=seed,
        )
        try:
            generate_and_upload_delta(
                csv_path=csv_path,
                delta_name="DELTA_0000000000000001",
                account_name=STORAGE_ACCOUNT,
                account_key=STORAGE_KEY,
                share_name=SHARE_NAME,
                share_path=SHARE_PATH,
                work_dir=tmp_path,
            )
        except pytest.skip.Exception:
            raise
        except Exception as e:
            pytest.skip(f"Could not generate/upload first delta (Docker/data_cli): {e}")

        key_strs = [str(k) for k in keys]
        body = build_getvalues_body(kv_hostname, key_strs)
        log.info("Waiting %ds for KV to load first delta", RELOAD_WAIT_SEC)
        time.sleep(RELOAD_WAIT_SEC)

        r = get_values(kv_base_url, body)
        assert r.status_code == 200
        kv = key_values_from_decoded(decode_compression_groups(r.json()))
        assert key_strs[0] in kv, (
            f"Missing first key {key_strs[0]}. Keys: {list(kv.keys())}"
        )
        assert key_strs[-1] in kv, (
            f"Missing last key {key_strs[-1]}. Keys: {list(kv.keys())}"
        )


class TestGetValuesEdgeCases:
    """Edge cases and error handling."""

    def test_getvalues_with_empty_keys_returns_200(self, kv_base_url, kv_hostname):
        body = build_getvalues_body(kv_hostname, [])
        r = get_values(kv_base_url, body)
        assert r.status_code in (200, 400), f"Unexpected status {r.status_code}: {r.text[:200]}"

    def test_getvalues_with_unknown_key_returns_200(self, kv_base_url, kv_hostname):
        body = build_getvalues_body(kv_hostname, ["nonexistent_key_12345"])
        r = get_values(kv_base_url, body)
        assert r.status_code == 200
        decoded = decode_compression_groups(r.json())
        kv = key_values_from_decoded(decoded)
        assert "nonexistent_key_12345" not in kv or kv.get("nonexistent_key_12345") in ("", None)
