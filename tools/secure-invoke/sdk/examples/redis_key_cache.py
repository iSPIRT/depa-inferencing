"""Example: back the SDK's public-key cache with Redis.

The SDK ships no Redis dependency; caching is pluggable. Implement the tiny
``KeyCache`` interface and hand it to ``SecureInvokeClient(key_cache=...)``. The
SDK still decides the TTL (honoring the KMS response Cache-Control/Expires, or
the configured fallback) and passes it to ``set``.

    pip install redis

Run:
    python examples/redis_key_cache.py
"""

from __future__ import annotations

import json
from typing import List, Optional

import redis  # type: ignore  # `pip install redis`

from depa_secure_invoke import (
    KeyCache,
    PublicKey,
    SecureInvokeClient,
    SecureInvokeConfig,
)


class RedisKeyCache(KeyCache):
    """A KMS public-key cache stored in Redis (shared across processes/hosts)."""

    def __init__(self, url: str = "redis://localhost:6379/0", prefix: str = "si:kms:"):
        self._redis = redis.Redis.from_url(url)
        self._prefix = prefix

    def get(self, key: str) -> Optional[List[PublicKey]]:
        raw = self._redis.get(self._prefix + key)
        if not raw:
            return None
        items = json.loads(raw)
        return [
            PublicKey(key_id=i["key_id"], public_key=i["public_key"]) for i in items
        ]

    def set(self, key: str, value: List[PublicKey], ttl: int) -> None:
        if ttl <= 0:
            return
        # Redis handles expiry for us via SETEX.
        self._redis.setex(
            self._prefix + key, ttl, json.dumps([dict(v) for v in value])
        )


def main() -> None:
    cfg = SecureInvokeConfig(
        kms_host="https://p3dx-kms.iudx.org.in",
        kms_keys_endpoint="/app/listpubkeys",
        offer_host="ispirt-ci.bfe.buyer.iudx.org.in:443",
        protocol="grpc",
        cache_ttl=15 * 60,  # fallback when the KMS sends no Cache-Control
    )

    client = SecureInvokeClient(cfg, key_cache=RedisKeyCache())

    # First call hits the KMS and populates Redis; subsequent calls (even from
    # other processes/hosts) reuse the cached key until it expires.
    key = client.public_key()
    print("key_id:", key.key_id)

    # --- Alternative: manage caching entirely yourself -----------------------
    # If you'd rather not use a KeyCache at all, fetch once and pass the key back
    # on every call; the SDK then never touches the KMS or any cache:
    #
    #   key = client.public_key()          # store this in Redis however you like
    #   client.invoke(request, public_key=key)


if __name__ == "__main__":
    main()
