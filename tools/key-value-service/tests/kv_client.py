"""
Client helpers for the key-value service GetValues API.
See: https://github.com/iSPIRT/protected-auction-key-value-service/blob/main/docs/testing_the_query_protocol.md
"""
import base64
import json
from typing import Any

import requests


def get_values(base_url: str, body: dict[str, Any], timeout: int = 30) -> requests.Response:
    """Send PUT /v2/getvalues and return the response."""
    url = f"{base_url.rstrip('/')}/v2/getvalues"
    return requests.put(url, json=body, timeout=timeout, headers={"Content-Type": "application/json"})


def build_getvalues_body(hostname: str, keys: list[str]) -> dict[str, Any]:
    """Build the JSON body for GetValues (partitions with two argument groups per partition)."""
    args = [
        {"tags": ["structured", "groupNames"], "data": keys},
        {"tags": ["custom", "keys"], "data": keys},
    ]
    return {
        "metadata": {"hostname": hostname},
        "partitions": [
            {"id": i, "compressionGroupId": 0, "arguments": args}
            for i in range(2)
        ],
    }


def decode_compression_groups(response_json: dict) -> list[dict]:
    """
    Decode compressionGroups[].content (base64) into Python dicts.
    Returns list of decoded payloads (one per compression group).
    """
    groups = response_json.get("compressionGroups") or []
    decoded = []
    for g in groups:
        b64 = g.get("content")
        if not b64:
            decoded.append({})
            continue
        try:
            raw = base64.b64decode(b64)
            decoded.append(json.loads(raw))
        except Exception:
            decoded.append({"raw": raw.decode("utf-8", errors="replace") if isinstance(raw, bytes) else str(raw)})
    return decoded


def _extract_kv_from_mapping(kv: dict, result: dict) -> None:
    """Merge keyValues / kvPairs mapping into result (key -> value string)."""
    for k, v in (kv or {}).items():
        if isinstance(v, dict) and "value" in v:
            result[k] = v["value"]
        else:
            result[k] = str(v)


def key_values_from_decoded(decoded: list) -> dict[str, str]:
    """
    Extract key -> value mapping from decoded GetValues payload(s).
    Handles:
    - Top-level "kvPairs" (e.g. { "kvPairs": { "key": { "value": "..." } } }).
    - List of partition-like objects or dict with "partitions" (keyGroupOutputs[].keyValues).
    """
    result = {}
    for payload in decoded:
        if not isinstance(payload, (list, dict)):
            continue
        # Single object with top-level kvPairs (some KV implementations)
        if isinstance(payload, dict) and "kvPairs" in payload:
            _extract_kv_from_mapping(payload["kvPairs"], result)
            continue
        parts = payload if isinstance(payload, list) else (payload.get("partitions") or [payload])
        for part in parts:
            if not isinstance(part, dict):
                continue
            if "kvPairs" in part:
                _extract_kv_from_mapping(part["kvPairs"], result)
            for out in (part.get("keyGroupOutputs") or []):
                _extract_kv_from_mapping(out.get("keyValues"), result)
    return result
