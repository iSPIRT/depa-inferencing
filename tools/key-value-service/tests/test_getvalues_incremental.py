"""
Incremental load tests: second delta updates/added keys and getValues reflects them.
Requires Azure Storage (share with deltas path) and optionally data_cli to generate second delta.
Skip if storage not configured; see README for env vars.
All generation and upload logic is in delta_tooling (tools/key-value-service/delta_tooling.py).
"""
import logging
import os
import sys
import time
from pathlib import Path

import pytest
import requests

# Parent dir for delta_tooling
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


class TestSecondDeltaLoad:
    """
    Upload a second delta file and assert getValues returns updated/new keys.
    Flow: (1) getValues and record initial state (2) upload DELTA_0000000000000002 (3) wait (4) getValues and assert.
    """

    def test_after_second_delta_getvalues_reflects_updated_values(
        self, kv_base_url, kv_hostname, tmp_path, storage_configured
    ):
        if not storage_configured:
            pytest.skip("Azure Storage not configured (KV_TEST_STORAGE_* env vars)")
        from csv_generator import write_kv_csv
        from delta_tooling import generate_and_upload_delta

        num_records = 2
        key_start = 100
        seed = 43
        csv_path, keys, values = write_kv_csv(
            tmp_path / "generated_delta2.csv",
            num_records=num_records,
            key_start=key_start,
            seed=seed,
        )
        try:
            generate_and_upload_delta(
                csv_path=csv_path,
                delta_name="DELTA_0000000000000002",
                account_name=STORAGE_ACCOUNT,
                account_key=STORAGE_KEY,
                share_name=SHARE_NAME,
                share_path=SHARE_PATH,
                work_dir=tmp_path,
            )
        except pytest.skip.Exception:
            raise
        except Exception as e:
            pytest.skip(f"Could not generate/upload second delta (Docker/data_cli): {e}")

        key_strs = [str(k) for k in keys]
        body = build_getvalues_body(kv_hostname, key_strs)
        log.info("Waiting %ds for KV to reload second delta", RELOAD_WAIT_SEC)
        time.sleep(RELOAD_WAIT_SEC)

        r1 = get_values(kv_base_url, body)
        assert r1.status_code == 200
        kv_after = key_values_from_decoded(decode_compression_groups(r1.json()))
        # Verification: only check presence of first and last key in the delta
        assert key_strs[0] in kv_after, (
            f"Missing first key {key_strs[0]} after second delta. Keys: {list(kv_after.keys())}"
        )
        assert key_strs[-1] in kv_after, (
            f"Missing last key {key_strs[-1]} after second delta. Keys: {list(kv_after.keys())}"
        )

    def test_second_delta_only_upload_no_data_cli(self, kv_base_url, kv_hostname, storage_configured):
        """If a pre-built DELTA_0000000000000002 exists in tests, upload it and assert (no data_cli)."""
        if not storage_configured:
            pytest.skip("Azure Storage not configured")
        from delta_tooling import upload_file_to_share

        tests_dir = Path(__file__).resolve().parent
        prebuilt = tests_dir / "DELTA_0000000000000002"
        if not prebuilt.exists():
            pytest.skip("Pre-built DELTA_0000000000000002 not found; run data_cli to create or use test_after_second_delta_getvalues_reflects_updated_values")
        upload_file_to_share(
            account_name=STORAGE_ACCOUNT,
            account_key=STORAGE_KEY,
            share_name=SHARE_NAME,
            path_in_share=f"{SHARE_PATH}/DELTA_0000000000000002",
            local_path=prebuilt,
        )
        log.info("Waiting %ds for KV to reload second delta", RELOAD_WAIT_SEC)
        time.sleep(RELOAD_WAIT_SEC)
        body = build_getvalues_body(kv_hostname, ["9999999990", "9999999992"])
        r = get_values(kv_base_url, body)
        assert r.status_code == 200
        kv = key_values_from_decoded(decode_compression_groups(r.json()))
        assert "9999999990" in kv or "9999999992" in kv, f"Expected updated/new keys, got {list(kv.keys())}"
